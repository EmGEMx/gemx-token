// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20CustodianUpgradeable} from "../../src/ERC20CustodianUpgradeable.sol";
import {ERC20BlocklistUpgradeable} from "../../src/ERC20BlocklistUpgradeable.sol";
import {GEMxToken} from "../../src/GEMxToken.sol";
import {DeployToken} from "../../script/DeployToken.s.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract GEMxTokenTest is Test {
    GEMxToken private token;
    MockV3Aggregator private oracle;
    address admin = address(0x1);
    address minter = address(0x2);
    address pauser = address(0x3);
    address custodian = address(0x4);
    address limiter = address(0x5);
    address esuUpdater = address(0x6);
    address user = makeAddr("user");
    address anon = makeAddr("anon");

    function setUp() public {
        admin = makeAddr("Admin");

        DeployToken deployer = new DeployToken();
        token = deployer.run();
        oracle = MockV3Aggregator(token.getOracleAddress());

        // Grant roles
        vm.startPrank(DEFAULT_SENDER);
        token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.PAUSER_ROLE(), pauser);
        token.grantRole(token.CUSTODIAN_ROLE(), custodian);
        token.grantRole(token.LIMITER_ROLE(), limiter);
        token.grantRole(token.ESU_ROLE(), esuUpdater);
        vm.stopPrank();
    }

    // TODO: set up invariant testing. Inveriant of the system: it should never be possible to mint more than allowed by ESU and PoR!

    function _setProofOfReserve(int256 value) private {
        oracle.updateAnswer(value);
    }

    function testTokenProperties() public view {
        assertEq(token.name(), "EmGemX Switzerland");
        assertEq(token.symbol(), "EmCH");
        assertEq(token.decimals(), 18);
        (uint256 esu, uint256 esuPrecision) = token.getEsu();
        assertEq(esu, 1);
        assertEq(esuPrecision, 100);
    }

    function testMintRespectsProofOfReserve() public {
        int256 reserve = 1_000 ether;
        _setProofOfReserve(reserve);

        vm.startPrank(minter);
        token.mint(user, 500 ether);
        assertEq(token.totalSupply(), 500 ether);

        token.mint(user, 500 ether);
        assertEq(token.totalSupply(), 1_000 ether);

        vm.expectRevert(GEMxToken.NotEnoughReserve.selector);
        token.mint(user, 1);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 1_000 ether);
    }

    /*##################################################################################*/
    /*###################################### ESU #######################################*/
    /*##################################################################################*/

    function testOnlyEsuUpdaterCanUpdateEsuValue() public {
        (uint256 esu, uint256 esuPrecision) = token.getEsu();
        assertEq(esu, 1);
        assertEq(esuPrecision, 100);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.ESU_ROLE())
        );
        vm.prank(user);
        token.setEsu(9, 1000);

        // values should not have changed
        (esu, esuPrecision) = token.getEsu();
        assertEq(esu, 1);
        assertEq(esuPrecision, 100);

        // ACT
        vm.prank(esuUpdater);
        token.setEsu(9, 1000);

        (esu, esuPrecision) = token.getEsu();
        assertEq(esu, 9);
        assertEq(esuPrecision, 1000);
    }

    /*##################################################################################*/
    /*################################### MINT/BURN ####################################*/
    /*##################################################################################*/

    function testOnlyMinterCanMint() public {
        _setProofOfReserve(1_000 ether);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.MINTER_ROLE())
        );
        vm.prank(user);
        token.mint(user, 1_000 ether);
        assertEq(token.balanceOf(user), 0 ether);

        vm.prank(minter);
        token.mint(user, 1 ether);
        assertEq(token.balanceOf(user), 1 ether);
    }

    function testOnlyMinterCanBurn() public {
        _setProofOfReserve(1_000 ether);

        vm.prank(minter);
        token.mint(user, uint256(10 ether));

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.MINTER_ROLE())
        );
        vm.prank(user);
        token.burn(user, 1 ether);

        assertEq(token.balanceOf(user), 10 ether);

        vm.prank(minter);
        token.burn(user, 1 ether);

        assertEq(token.balanceOf(user), 9 ether);
    }

    /*##################################################################################*/
    /*################################# PAUSE/UNPAUSE ##################################*/
    /*##################################################################################*/

    function testOnlyPauserCanPause() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.PAUSER_ROLE())
        );
        vm.prank(user);
        token.pause();
        assertEq(token.paused(), false);

        vm.prank(pauser);
        token.pause();
        assertEq(token.paused(), true);
    }

    function testOnlyPauserCanUnpause() public {
        vm.prank(pauser);
        token.pause();
        assertEq(token.paused(), true);

        // ACT
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.PAUSER_ROLE())
        );
        vm.prank(user);
        token.pause();
        assertEq(token.paused(), true);

        vm.prank(pauser);
        token.unpause();
        assertEq(token.paused(), false);
    }

    function testTransferWhenPauseUnpause() public {
        _setProofOfReserve(1_000 ether);

        vm.prank(minter);
        token.mint(user, uint256(10 ether));

        address receiver = makeAddr("receiver");
        vm.prank(user);
        token.transfer(receiver, 1 ether);
        assertEq(token.balanceOf(receiver), 1 ether);

        vm.prank(pauser);
        token.pause();
        assertEq(token.paused(), true);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(user);
        token.transfer(receiver, 1 ether);
        assertEq(token.balanceOf(receiver), 1 ether);

        vm.prank(pauser);
        token.unpause();
        assertEq(token.paused(), false);

        vm.prank(user);
        token.transfer(receiver, 1 ether);
        assertEq(token.balanceOf(receiver), 2 ether);
    }

    /*##################################################################################*/
    /*################################ FREEZE/UNFREEZE #################################*/
    /*##################################################################################*/

    // TODO: split into separate tests once modifier with test setup is implemented
    function testOnlyCustodianCanFreezeAndUnfreeze() public {
        _setProofOfReserve(1_000 ether);

        vm.prank(minter);
        token.mint(user, uint256(10 ether));

        // freeze not allowed
        vm.expectRevert(ERC20CustodianUpgradeable.ERC20NotCustodian.selector);
        vm.prank(anon);
        token.freeze(user, 1 ether);
        assertEq(token.frozen(user), 0);
        assertEq(token.availableBalance(user), 10 ether);

        // freeze allowed
        //vm.expectEmit();
        //emit ERC20CustodianUpgradeable.TokensFrozen(user, 1 ether);
        vm.prank(custodian);
        token.freeze(user, 1 ether);
        assertEq(token.frozen(user), 1 ether);
        assertEq(token.availableBalance(user), 9 ether);

        // unfreeze not allowed
        vm.expectRevert(ERC20CustodianUpgradeable.ERC20NotCustodian.selector);
        vm.prank(anon);
        token.freeze(user, 0 ether);
        assertEq(token.frozen(user), 1 ether);
        assertEq(token.availableBalance(user), 9 ether);

        // unfreeze allowed
        //vm.expectEmit();
        //emit ERC20CustodianUpgradeable.TokensFrozen(user, 0);
        vm.prank(custodian);
        token.freeze(user, 0 ether);
        assertEq(token.frozen(user), 0);
        assertEq(token.availableBalance(user), 10 ether);
    }

    function testTransferWhenAmountFrozen() public {
        _setProofOfReserve(1_000 ether);

        vm.prank(minter);
        token.mint(user, uint256(10 ether));

        // freeze allowed
        vm.prank(custodian);
        token.freeze(user, 8 ether);
        assertEq(token.frozen(user), 8 ether);
        assertEq(token.availableBalance(user), 2 ether);

        // try to transfer with amount exceeding frozen balance
        vm.expectRevert(
            abi.encodeWithSelector(ERC20CustodianUpgradeable.ERC20InsufficientUnfrozenBalance.selector, user)
        );
        vm.prank(user);
        token.transfer(anon, 3 ether);

        // try to transfer with available balance left -> should work
        vm.prank(user);
        token.transfer(anon, 2 ether);

        assertEq(token.availableBalance(user), 0 ether);
        assertEq(token.availableBalance(anon), 2 ether);
    }

    /*##################################################################################*/
    /*################################# BLOCK/UNBLOCK ##################################*/
    /*##################################################################################*/

    function testOnlyLimiterCanBlockUser() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.LIMITER_ROLE())
        );
        vm.prank(user);
        token.blockUser(anon);
        assertEq(token.blocked(anon), false);

        vm.prank(limiter);
        token.blockUser(anon);
        assertEq(token.blocked(anon), true);
    }

    function testOnlyLimiterCanUnblockUser() public {
        vm.prank(limiter);
        token.blockUser(anon);
        assertEq(token.blocked(anon), true);

        // ACT
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.LIMITER_ROLE())
        );
        vm.prank(user);
        token.unblockUser(anon);
        assertEq(token.blocked(anon), true);

        vm.prank(limiter);
        token.unblockUser(anon);
        assertEq(token.blocked(anon), false);
    }

    function testTransferWhenUserBlocked() public {
        _setProofOfReserve(1_000 ether);

        vm.prank(minter);
        token.mint(user, uint256(10 ether));

        // send some tokens so sending can be tested when user gets blocked
        address receiver = makeAddr("receiver");
        vm.prank(user);
        token.transfer(receiver, 1 ether);
        assertEq(token.balanceOf(receiver), 1 ether);

        vm.prank(limiter);
        token.blockUser(receiver);
        assertEq(token.blocked(receiver), true);

        // neither sending nor receiving should work, basically receiver should keep 1 as initially sent!

        // receiving
        vm.expectRevert(abi.encodeWithSelector(ERC20BlocklistUpgradeable.ERC20Blocked.selector, receiver));
        vm.prank(user);
        token.transfer(receiver, 1 ether);
        assertEq(token.balanceOf(receiver), 1 ether, "Tokens should not be received");

        // sending
        vm.expectRevert(abi.encodeWithSelector(ERC20BlocklistUpgradeable.ERC20Blocked.selector, receiver));
        vm.prank(receiver);
        token.transfer(user, 1 ether);
        assertEq(token.balanceOf(receiver), 1 ether, "Tokens should not be moved");

        vm.prank(limiter);
        token.unblockUser(receiver);
        assertEq(token.blocked(receiver), false);

        // receiving should work again
        vm.prank(user);
        token.transfer(receiver, 1 ether);
        assertEq(token.balanceOf(receiver), 2 ether);

        // sending should work again
        vm.prank(receiver);
        token.transfer(user, 1 ether);
        assertEq(token.balanceOf(receiver), 1 ether);
    }

    function testErc20ApproveWhenUserBlocked() public {
        _setProofOfReserve(1_000 ether);

        vm.prank(minter);
        token.mint(user, uint256(10 ether));

        vm.prank(limiter);
        token.blockUser(user);
        assertEq(token.blocked(user), true);

        // user should not be able approve others in case he is blocked
        vm.expectRevert(abi.encodeWithSelector(ERC20BlocklistUpgradeable.ERC20Blocked.selector, user));
        vm.prank(user);
        token.approve(anon, 1 ether);
        assertEq(token.allowance(user, anon), 0);

        vm.prank(limiter);
        token.unblockUser(user);
        assertEq(token.blocked(user), false);

        vm.prank(user);
        token.approve(anon, 1 ether);
        assertEq(token.allowance(user, anon), 1 ether);
    }

    /*##################################################################################*/
    /*##################################### RBAC #######################################*/
    /*##################################################################################*/

    function testAdminCanGrantRoles() public {
        address newMinter = address(0x5);

        bytes32 role = token.MINTER_ROLE();
        vm.prank(admin);
        token.grantRole(role, newMinter);
        assertTrue(token.hasRole(role, newMinter));

        role = token.PAUSER_ROLE();
        vm.prank(admin);
        token.grantRole(role, newMinter);
        assertTrue(token.hasRole(role, newMinter));

        role = token.CUSTODIAN_ROLE();
        vm.prank(admin);
        token.grantRole(role, newMinter);
        assertTrue(token.hasRole(role, newMinter));

        role = token.LIMITER_ROLE();
        vm.prank(admin);
        token.grantRole(role, newMinter);
        assertTrue(token.hasRole(role, newMinter));

        role = token.ESU_ROLE();
        vm.prank(admin);
        token.grantRole(role, newMinter);
        assertTrue(token.hasRole(role, newMinter));
    }

    function testAdminCanRevokeRoles() public {
        bytes32 minteRole = token.MINTER_ROLE();
        assertTrue(token.hasRole(minteRole, minter));
        vm.prank(admin);
        token.revokeRole(minteRole, minter);
        assertFalse(token.hasRole(minteRole, minter));

        bytes32 pauserRole = token.PAUSER_ROLE();
        assertTrue(token.hasRole(pauserRole, pauser));
        vm.prank(admin);
        token.revokeRole(pauserRole, pauser);
        assertFalse(token.hasRole(pauserRole, pauser));

        bytes32 custodianRole = token.CUSTODIAN_ROLE();
        assertTrue(token.hasRole(custodianRole, custodian));
        vm.prank(admin);
        token.revokeRole(custodianRole, custodian);
        assertFalse(token.hasRole(custodianRole, custodian));

        bytes32 limiterRole = token.LIMITER_ROLE();
        assertTrue(token.hasRole(limiterRole, limiter));
        vm.prank(admin);
        token.revokeRole(limiterRole, limiter);
        assertFalse(token.hasRole(limiterRole, limiter));

        bytes32 esuUpdateRole = token.ESU_ROLE();
        assertTrue(token.hasRole(esuUpdateRole, esuUpdater));
        vm.prank(admin);
        token.revokeRole(esuUpdateRole, esuUpdater);
        assertFalse(token.hasRole(esuUpdateRole, esuUpdater));
    }
}
