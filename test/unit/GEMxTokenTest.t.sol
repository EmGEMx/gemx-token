// SPDX-License-Identifier: UNLICENSED
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
    address esuPerTokenModifier = address(0x6);
    address user = makeAddr("user");
    address anon = makeAddr("anon");

    event TokensFrozen(address indexed user, uint256 amount);

    function setUp() public {
        admin = makeAddr("Admin");

        vm.setEnv("TOKEN_NAME", "EmGEMx Switzerland");
        vm.setEnv("TOKEN_SYMBOL", "EmCH");
        DeployToken deployer = new DeployToken();
        token = deployer.run();
        oracle = MockV3Aggregator(token.getOracleAddress());

        vm.chainId(token.PARENT_CHAIN_ID()); // set chain token's parent chain to enable full feature set with minting restrictio

        // Grant roles
        vm.startPrank(DEFAULT_SENDER);
        token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.PAUSER_ROLE(), pauser);
        token.grantRole(token.CUSTODIAN_ROLE(), custodian);
        token.grantRole(token.LIMITER_ROLE(), limiter);
        token.grantRole(token.ESU_PER_TOKEN_MODIFIER_ROLE(), esuPerTokenModifier);
        vm.stopPrank();
    }

    // TODO: set up invariant testing. Inveriant of the system: it should never be possible to mint more than allowed by ESU and PoR!

    function testTokenProperties() public view {
        assertEq(token.name(), "EmGEMx Switzerland");
        assertEq(token.symbol(), "EmCH");
        assertEq(token.decimals(), 8);
        (uint256 esu, uint256 esuPrecision) = token.getEsuPerToken();
        assertEq(esu, 1, "Initial EsuPerToken is 0.01");
        assertEq(esuPrecision, 100, "Initial EsuPerToken is 0.01");
    }

    /*##################################################################################*/
    /*################################# Oracle Update ##################################*/
    /*##################################################################################*/

    function testOnlyAdminCanUpdateOracle() public {
        address currentOracleAddress = token.getOracleAddress();
        MockV3Aggregator newOracle = new MockV3Aggregator(1000);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.DEFAULT_ADMIN_ROLE())
        );
        vm.prank(user);
        token.setOracleAddress(address(newOracle));
        assertEq(token.getOracleAddress(), currentOracleAddress);

        vm.prank(admin);
        token.setOracleAddress(address(newOracle));
        assertEq(token.getOracleAddress(), address(newOracle));
    }

    /*##################################################################################*/
    /*###################################### ESU #######################################*/
    /*##################################################################################*/

    function testMintOnAvalancheParentChainRespectsEsuOracle_And_EsuPerTokenSetting() public {
        vm.chainId(token.PARENT_CHAIN_ID());

        int256 esu = 100 ether;
        _setEsu(esu);

        uint256 maxSupply = token.getMaxSupply();
        console.log("Allowed MaxSupply:", maxSupply);
        assertEq(maxSupply, 10_000 ether, "Parameters changed - Arrange needs to be adjusted");

        vm.startPrank(minter);
        token.mint(user, 5000 ether);
        assertEq(token.totalSupply(), 5000 ether);

        token.mint(user, 5000 ether);
        assertEq(token.totalSupply(), 10_000 ether);

        // ACT
        vm.expectRevert(GEMxToken.NotEnoughReserve.selector);
        token.mint(user, 1);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 10_000 ether);
    }

    function testMintOnChildChainHasNoRestriction() public {
        vm.chainId(1); // e.g. ethereum mainnet

        int256 esu = 100 ether;
        _setEsu(esu);

        uint256 maxSupply = token.getMaxSupply();
        assertEq(maxSupply, type(uint256).max);

        // ACT
        vm.startPrank(minter);
        token.mint(user, 1_000_000 ether);
        assertEq(token.totalSupply(), 1_000_000 ether);

        assertEq(token.balanceOf(user), 1_000_000 ether);
    }

    function _setEsu(int256 value) private {
        oracle.updateAnswer(value);
    }

    function testOnlyEsuPerTokenModifierCanUpdateEsuPerTokenValue() public {
        (uint256 esu, uint256 esuPrecision) = token.getEsuPerToken();
        assertEq(esu, 1);
        assertEq(esuPrecision, 100);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.ESU_PER_TOKEN_MODIFIER_ROLE()
            )
        );
        vm.prank(user);
        token.setEsuPerToken(9, 10000);

        // values should not have changed
        (esu, esuPrecision) = token.getEsuPerToken();
        assertEq(esu, 1, "Esu value should not have changed");
        assertEq(esuPrecision, 100, "Esu precision should not have changed");

        // ACT
        vm.prank(esuPerTokenModifier);
        token.setEsuPerToken(9, 10000);

        (esu, esuPrecision) = token.getEsuPerToken();
        assertEq(esu, 9);
        assertEq(esuPrecision, 10000);
    }

    function testVerifyEsuCalculation() public {
        vm.chainId(token.PARENT_CHAIN_ID());

        (uint256 esu, uint256 esuPrecision) = token.getEsuPerToken();
        assertEq(esu, 1);
        assertEq(esuPrecision, 100); // 0.01 ether

        _setEsu(2521130000000000000000); // 2521.13
        uint256 maxSupplyWei = token.getMaxSupply();
        assertEq(maxSupplyWei, 252_113 ether);

        _setEsu(2521130000000000000000); // 2521.13
        vm.prank(esuPerTokenModifier);
        token.setEsuPerToken(99, 10000); // 0.0099
        maxSupplyWei = token.getMaxSupply();
        assertEq(roundTwoDecimals(maxSupplyWei), 254_659_60 ether / 100); // 254659.60

        _setEsu(3871130000000000000000); // 3871.13
        vm.prank(esuPerTokenModifier);
        token.setEsuPerToken(9801, 1_000_000); // 0.009801
        maxSupplyWei = token.getMaxSupply();
        assertEq(roundTwoDecimals(maxSupplyWei), 394_972_96 ether / 100); // 394972.96
    }

    function roundTwoDecimals(uint256 value) private pure returns (uint256) {
        // Define the rounding factor for 0.01 ether (10^16 wei)
        uint256 roundingFactor = 10 ** 16;

        // Add half of the rounding factor to the value for proper rounding
        uint256 roundedValue = (value + (roundingFactor / 2)) / roundingFactor;

        // Multiply back to get the rounded wei value
        return roundedValue * roundingFactor;
    }

    /*##################################################################################*/
    /*################################### MINT/BURN ####################################*/
    /*##################################################################################*/

    function testOnlyMinterCanMint() public {
        _setEsu(1_000 ether);

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
        _setEsu(1_000 ether);

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
        _setEsu(1_000 ether);

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
        _setEsu(1_000 ether);

        vm.prank(minter);
        token.mint(user, uint256(10 ether));

        // freeze not allowed
        vm.expectRevert(ERC20CustodianUpgradeable.ERC20NotCustodian.selector);
        vm.prank(anon);
        token.freeze(user, 1 ether);
        assertEq(token.frozen(user), 0);
        assertEq(token.availableBalance(user), 10 ether);

        // freeze allowed
        vm.expectEmit();
        emit TokensFrozen(user, 1 ether);
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
        vm.expectEmit();
        emit TokensFrozen(user, 0);
        vm.prank(custodian);
        token.freeze(user, 0 ether);
        assertEq(token.frozen(user), 0);
        assertEq(token.availableBalance(user), 10 ether);
    }

    function testTransferWhenAmountFrozen() public {
        _setEsu(1_000 ether);

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

    function testCannotFreezeMoreThanAvailable() public {
        _setEsu(1_000 ether);

        vm.prank(minter);
        token.mint(user, uint256(10 ether));

        // try to freeze more than user has balance
        vm.expectRevert(
            abi.encodeWithSelector(ERC20CustodianUpgradeable.ERC20InsufficientUnfrozenBalance.selector, user)
        );
        vm.prank(custodian);
        token.freeze(user, 11 ether);

        assertEq(token.frozen(user), 0 ether);
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
        _setEsu(1_000 ether);

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
        _setEsu(1_000 ether);

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

        role = token.ESU_PER_TOKEN_MODIFIER_ROLE();
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

        bytes32 esuPerTokenModifierRole = token.ESU_PER_TOKEN_MODIFIER_ROLE();
        assertTrue(token.hasRole(esuPerTokenModifierRole, esuPerTokenModifier));
        vm.prank(admin);
        token.revokeRole(esuPerTokenModifierRole, esuPerTokenModifier);
        assertFalse(token.hasRole(esuPerTokenModifierRole, esuPerTokenModifier));
    }
}
