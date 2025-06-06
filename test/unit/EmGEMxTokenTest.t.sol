// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20FreezableUpgradeable} from "../../src/ERC20FreezableUpgradeable.sol";
import {ERC20BlocklistUpgradeable} from "../../src/ERC20BlocklistUpgradeable.sol";
import {EmGEMxToken} from "../../src/EmGEMxToken.sol";
import {DeployToken} from "../../script/DeployToken.s.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract EmGEMxTokenTest is Test {
    EmGEMxToken private token;
    MockV3Aggregator private oracle;
    address admin = address(0x1);
    address minter = address(0x2);
    address pauser = address(0x3);
    address freezer = address(0x4);
    address limiter = address(0x5);
    address esuPerTokenModifier = address(0x6);
    address redeemer = address(0x7);

    address redeemAddress = makeAddr("redeemAddress");
    address user = makeAddr("user");
    address anon = makeAddr("anon");

    uint256 private constant ONE_TOKEN = 100000000; // 8 decimals -> 1234000000 = 12.34

    event TokensFrozen(address indexed user, uint256 amount);
    event OracleAddressChanged(string oldAddres, string newAddress);
    event EsuPerTokenChanged(uint256 value, uint256 precision);
    event RedeemAddressChanged(address oldAddress, address newAddress);

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
        token.grantRole(token.FREEZER_ROLE(), freezer);
        token.grantRole(token.LIMITER_ROLE(), limiter);
        token.grantRole(token.ESU_PER_TOKEN_MODIFIER_ROLE(), esuPerTokenModifier);
        token.grantRole(token.REDEEMER_ROLE(), redeemer);
        vm.stopPrank();
    }

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
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(user);
        token.setOracleAddress(address(newOracle));
        assertEq(token.getOracleAddress(), currentOracleAddress);

        vm.prank(admin);
        token.setOracleAddress(address(newOracle));
        assertEq(token.getOracleAddress(), address(newOracle));
    }

    function testSetOracleAddress_CannotBeCalledOnChildChain() public {
        vm.chainId(1); // non parent chain

        vm.prank(admin);
        vm.expectRevert(EmGEMxToken.EmGEMxToken__ParentChainOnly.selector);
        token.setOracleAddress(makeAddr("newOracleAddress"));
    }

    /*##################################################################################*/
    /*###################################### ESU #######################################*/
    /*##################################################################################*/

    function testMintOnAvalancheParentChainRespectsEsuOracle_And_EsuPerTokenSetting() public {
        vm.chainId(token.PARENT_CHAIN_ID());

        _setEsu(100 * ONE_TOKEN); // 100

        uint256 maxSupply = token.getMaxSupply();
        console.log("Allowed MaxSupply:", maxSupply);
        assertEq(maxSupply, 10_000 * ONE_TOKEN, "Parameters changed - Arrange needs to be adjusted");

        vm.startPrank(minter);
        token.mint(user, 5000 * ONE_TOKEN);
        assertEq(token.totalSupply(), 5000 * ONE_TOKEN);

        token.mint(user, 5000 * ONE_TOKEN);
        assertEq(token.totalSupply(), 10_000 * ONE_TOKEN);

        // ACT
        vm.expectRevert(EmGEMxToken.EmGEMxToken__NotEnoughReserve.selector);
        token.mint(user, 1);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 10_000 * ONE_TOKEN);
    }

    function testMintOnChildChainHasNoRestriction() public {
        vm.chainId(1); // e.g. ethereum mainnet

        _setEsu(100 * ONE_TOKEN); // 100

        uint256 maxSupply = token.getMaxSupply();
        assertEq(maxSupply, type(uint256).max);

        // ACT
        vm.startPrank(minter);
        token.mint(user, 1_000_000 * ONE_TOKEN);
        assertEq(token.totalSupply(), 1_000_000 * ONE_TOKEN);

        assertEq(token.balanceOf(user), 1_000_000 * ONE_TOKEN);
    }

    function _setEsu(uint256 value) private {
        oracle.updateAnswer(int256(value));
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

        (esu, esuPrecision) = token.getEsuPerToken();
        assertEq(esu, 1, "Esu value should not have changed");
        assertEq(esuPrecision, 100, "Esu precision should not have changed");

        // ACT
        vm.prank(esuPerTokenModifier);
        vm.expectEmit();
        emit EsuPerTokenChanged(9, 10000);
        token.setEsuPerToken(9, 10000);

        (esu, esuPrecision) = token.getEsuPerToken();
        assertEq(esu, 9);
        assertEq(esuPrecision, 10000);
    }

    function testEsuPerToken_CannotBeUpdatedOnChildChain() public {
        (uint256 esu, uint256 esuPrecision) = token.getEsuPerToken();
        assertEq(esu, 1);
        assertEq(esuPrecision, 100);

        vm.chainId(1); // non parent chain

        vm.prank(esuPerTokenModifier);
        vm.expectRevert(EmGEMxToken.EmGEMxToken__ParentChainOnly.selector);
        token.setEsuPerToken(9, 10000);

        (esu, esuPrecision) = token.getEsuPerToken();
        assertEq(esu, 1, "Esu value should not have changed");
        assertEq(esuPrecision, 100, "Esu precision should not have changed");
    }

    function testVerifyEsuCalculation() public {
        vm.chainId(token.PARENT_CHAIN_ID());

        (uint256 esu, uint256 esuPrecision) = token.getEsuPerToken();
        assertEq(esu, 1);
        assertEq(esuPrecision, 100); // 0.01

        uint256 decimals = token.decimals();

        _setEsu(252113 * ONE_TOKEN / 100); // 2521.13
        uint256 maxSupplyWei = token.getMaxSupply();
        assertEq(maxSupplyWei, 252_113 * 10 ** decimals);

        _setEsu(252113 * ONE_TOKEN / 100); // 2521.13
        vm.prank(esuPerTokenModifier);
        token.setEsuPerToken(99, 10000); // 0.0099
        maxSupplyWei = token.getMaxSupply();
        assertEq(roundTwoDecimals(maxSupplyWei), 254_659_60 * ONE_TOKEN / 100); // 254659.60

        _setEsu(387113 * ONE_TOKEN / 100); // 3871.13
        vm.prank(esuPerTokenModifier);
        token.setEsuPerToken(9801, 1_000_000); // 0.009801
        maxSupplyWei = token.getMaxSupply();
        assertEq(roundTwoDecimals(maxSupplyWei), 394_972_96 * ONE_TOKEN / 100); // 394972.96
    }

    function testStaleOracleReverts() public {
        vm.chainId(token.PARENT_CHAIN_ID());

        _setEsu(1000 * ONE_TOKEN); // 1000
        (uint80 roundId, int256 answer, /*uint256 startedAt*/, uint256 updatedAt, uint80 answeredInRound) =
            oracle.getRoundData(1);

        oracle.updateRoundData(roundId, 0, updatedAt, answeredInRound);
        vm.expectRevert(bytes("PoR: answer is zero"));
        uint256 maxSupplyWei = token.getMaxSupply();

        oracle.updateRoundData(roundId, answer, 0, answeredInRound);
        vm.expectRevert(bytes("PoR: updatedAt is zero"));
        maxSupplyWei = token.getMaxSupply();

        oracle.updateRoundData(roundId, answer, updatedAt, answeredInRound);
        oracle.setStale();
        vm.expectRevert(bytes("PoR: data is stale"));
        maxSupplyWei = token.getMaxSupply();
    }

    function roundTwoDecimals(uint256 value) private pure returns (uint256) {
        // Define the rounding factor for 0.01 token (10^6 wei as 8 token decimals)
        uint256 roundingFactor = 10 ** 6;

        // Add half of the rounding factor to the value for proper rounding
        uint256 roundedValue = (value + (roundingFactor / 2)) / roundingFactor;

        // Multiply back to get the rounded wei value
        return roundedValue * roundingFactor;
    }

    /*##################################################################################*/
    /*################################### MINT/BURN ####################################*/
    /*##################################################################################*/

    function testOnlyMinterCanMint() public {
        _setEsu(1000 * ONE_TOKEN); // 1000

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.MINTER_ROLE())
        );
        vm.prank(user);
        token.mint(user, 1_000 * ONE_TOKEN);
        assertEq(token.balanceOf(user), 0);

        vm.prank(minter);
        token.mint(user, 1 * ONE_TOKEN);
        assertEq(token.balanceOf(user), 1 * ONE_TOKEN);
    }

    function testOnlyMinterCanBurnOnChildChain() public {
        _setEsu(100000 * ONE_TOKEN / 100); // 1000
        vm.chainId(1); // burn restriction only in place on parent chain

        vm.prank(minter);
        token.mint(user, uint256(10 * ONE_TOKEN));

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.MINTER_ROLE())
        );
        vm.prank(user);
        token.burn(1 * ONE_TOKEN);

        assertEq(token.balanceOf(user), 10 * ONE_TOKEN);

        // add minter role to user -> now burning his tokens should be possible
        bytes32 role = token.MINTER_ROLE();
        vm.prank(admin);
        token.grantRole(role, user);
        assertTrue(token.hasRole(role, user));

        vm.prank(user);
        token.burn(1 * ONE_TOKEN);

        assertEq(token.balanceOf(user), 9 * ONE_TOKEN);
    }

    function testRegularUsersWithoutMinterRoleCannotBurnOnChildChain() public {
        // Set to a child chain (not the parent chain)
        vm.chainId(1); // Use a different chain ID than PARENT_CHAIN_ID (43114)

        address regularUser = makeAddr("regularUser");
        address otherUser = makeAddr("otherUser");

        // Verify users don't have minter role
        assertFalse(token.hasRole(token.MINTER_ROLE(), regularUser));
        assertFalse(token.hasRole(token.MINTER_ROLE(), otherUser));

        // Mint tokens to users on child chain (using account with minter role)
        vm.prank(minter);
        token.mint(regularUser, 100 * ONE_TOKEN);
        vm.prank(minter);
        token.mint(otherUser, 100 * ONE_TOKEN);

        // Regular user burns their own tokens despite not having minter role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, regularUser, token.MINTER_ROLE()
            )
        );
        vm.prank(regularUser);
        token.burn(30 * ONE_TOKEN);

        // Verify burn did not work
        assertEq(token.balanceOf(regularUser), 100 * ONE_TOKEN);

        // Set up for burnFrom - otherUser approves regularUser
        vm.prank(otherUser);
        token.approve(regularUser, 50 * ONE_TOKEN);

        // Regular user burns tokens from other user using burnFrom
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, regularUser, token.MINTER_ROLE()
            )
        );
        vm.prank(regularUser);
        token.burnFrom(otherUser, 40 * ONE_TOKEN);

        // Verify burnFrom did not work as minter role missing
        assertEq(token.balanceOf(otherUser), 100 * ONE_TOKEN);
        assertEq(token.allowance(otherUser, regularUser), 50 * ONE_TOKEN);

        // Explicitly assert that users without minter role cannot burn tokens on child chain
        assertTrue(
            token.balanceOf(regularUser) == 100 * ONE_TOKEN, "Regular user failed to burn tokens without minter role"
        );
        assertTrue(
            token.balanceOf(otherUser) == 100 * ONE_TOKEN,
            "Regular user unsuccessfully used burnFrom without minter role"
        );
    }

    /*##################################################################################*/
    /*#################################### Redeem ######################################*/
    /*##################################################################################*/

    function testOnlyAdminCanSetRedeemAddress() public {
        assertEq(token.getRedeemAddress(), address(0));
        address newRedeemAddress = makeAddr("newRedeemAddress");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(user);
        token.setRedeemAddress(newRedeemAddress);
        assertEq(token.getRedeemAddress(), address(0));

        vm.prank(admin);
        vm.expectEmit();
        emit RedeemAddressChanged(address(0), newRedeemAddress);
        token.setRedeemAddress(newRedeemAddress);
        assertEq(token.getRedeemAddress(), newRedeemAddress);
    }

    function testBurnOnParentChainOnlyAllowedOnRedeemAddress() public {
        _setEsu(100000 * ONE_TOKEN / 100); // 1000
        vm.chainId(token.PARENT_CHAIN_ID()); // burn restriction only in place on parent chain

        vm.prank(minter);
        token.mint(user, uint256(10 * ONE_TOKEN));

        // grant user minter rights so burn(amount) can be called
        bytes32 role = token.MINTER_ROLE();
        vm.prank(admin);
        token.grantRole(role, user);
        assertTrue(token.hasRole(role, user));

        vm.expectRevert(EmGEMxToken.EmGEMxToken__BurnOnParentChainNotAllowed.selector);
        vm.prank(user);
        token.burn(1 * ONE_TOKEN);
        assertEq(token.balanceOf(user), 10 * ONE_TOKEN, "balance should not change");

        // verify that also burnFrom is not possible
        address otherUser = makeAddr("otherUser");
        vm.prank(minter);
        token.mint(otherUser, 10 * ONE_TOKEN);
        // Set up for burnFrom - otherUser approves user
        vm.prank(otherUser);
        token.approve(user, 5 * ONE_TOKEN);

        vm.expectRevert(EmGEMxToken.EmGEMxToken__BurnOnParentChainNotAllowed.selector);
        vm.prank(user);
        token.burnFrom(otherUser, 4 * ONE_TOKEN);
        assertEq(token.balanceOf(otherUser), 10 * ONE_TOKEN, "balance should not change");
    }

    function testRedeem_WhenRedeemAddressNotSet_Reverts() public {
        _setEsu(100000 * ONE_TOKEN / 100); // 1000
        assertEq(token.getRedeemAddress(), address(0));

        vm.expectRevert(EmGEMxToken.EmGEMxToken__RedeemAddressNotSet.selector);
        vm.prank(redeemer);
        token.redeem(1 * ONE_TOKEN);
    }

    function testOnlyRedeemerCanRedeem() public {
        _setEsu(100000 * ONE_TOKEN / 100); // 1000
        vm.prank(admin);
        token.setRedeemAddress(redeemAddress);
        vm.prank(minter);
        token.mint(redeemAddress, 10 * ONE_TOKEN);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.REDEEMER_ROLE()
            )
        );
        vm.prank(user);
        token.redeem(1 * ONE_TOKEN);
        assertEq(token.balanceOf(redeemAddress), 10 * ONE_TOKEN, "balance should not change");

        vm.prank(redeemer);
        token.redeem(1 * ONE_TOKEN);
        assertEq(token.balanceOf(redeemAddress), 9 * ONE_TOKEN);
    }

    function testZeroAddressAsRedeemAddressReverts() public {
        assertEq(token.getRedeemAddress(), address(0));
        address newRedeemAddress = makeAddr("newRedeemAddress");

        vm.prank(admin);
        token.setRedeemAddress(newRedeemAddress);
        assertEq(token.getRedeemAddress(), newRedeemAddress);

        vm.expectRevert(abi.encodeWithSelector(EmGEMxToken.EmGEMxToken__InvalidAddress.selector, address(0)));
        vm.prank(admin);
        token.setRedeemAddress(address(0));
        assertEq(token.getRedeemAddress(), newRedeemAddress, "Addres should not change");
    }

    function testRedeem_CannotBeCalledOnChildChain() public {
        vm.chainId(1); // non parent chain

        vm.prank(redeemer);
        vm.expectRevert(EmGEMxToken.EmGEMxToken__ParentChainOnly.selector);
        token.redeem(1);
    }

    function testSetRedeemAddress_CannotBeCalledOnChildChain() public {
        vm.chainId(1); // non parent chain

        vm.prank(admin);
        vm.expectRevert(EmGEMxToken.EmGEMxToken__ParentChainOnly.selector);
        token.setRedeemAddress(makeAddr("newRedeemAddress"));
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
        _setEsu(100000 * ONE_TOKEN / 100); // 1000

        vm.prank(minter);
        token.mint(user, uint256(10 * ONE_TOKEN));

        address receiver = makeAddr("receiver");
        vm.prank(user);
        token.transfer(receiver, 1 * ONE_TOKEN);
        assertEq(token.balanceOf(receiver), 1 * ONE_TOKEN);

        vm.prank(pauser);
        token.pause();
        assertEq(token.paused(), true);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(user);
        token.transfer(receiver, 1 * ONE_TOKEN);
        assertEq(token.balanceOf(receiver), 1 * ONE_TOKEN);

        vm.prank(pauser);
        token.unpause();
        assertEq(token.paused(), false);

        vm.prank(user);
        token.transfer(receiver, 1 * ONE_TOKEN);
        assertEq(token.balanceOf(receiver), 2 * ONE_TOKEN);
    }

    /*##################################################################################*/
    /*################################ FREEZE/UNFREEZE #################################*/
    /*##################################################################################*/

    // TODO: split into separate tests once modifier with test setup is implemented
    function testOnlyfreezerCanFreezeAndUnfreeze() public {
        _setEsu(100000 * ONE_TOKEN / 100); // 1000

        vm.prank(minter);
        token.mint(user, uint256(10 * ONE_TOKEN));

        // freeze not allowed
        vm.expectRevert(ERC20FreezableUpgradeable.ERC20NotFreezer.selector);
        vm.prank(anon);
        token.freeze(user, 1 * ONE_TOKEN);
        assertEq(token.frozen(user), 0);
        assertEq(token.availableBalance(user), 10 * ONE_TOKEN);

        // freeze allowed
        vm.expectEmit();
        emit TokensFrozen(user, 1 * ONE_TOKEN);
        vm.prank(freezer);
        token.freeze(user, 1 * ONE_TOKEN);
        assertEq(token.frozen(user), 1 * ONE_TOKEN);
        assertEq(token.availableBalance(user), 9 * ONE_TOKEN);

        // unfreeze not allowed
        vm.expectRevert(ERC20FreezableUpgradeable.ERC20NotFreezer.selector);
        vm.prank(anon);
        token.freeze(user, 0 * ONE_TOKEN);
        assertEq(token.frozen(user), 1 * ONE_TOKEN);
        assertEq(token.availableBalance(user), 9 * ONE_TOKEN);

        // unfreeze allowed
        vm.expectEmit();
        emit TokensFrozen(user, 0);
        vm.prank(freezer);
        token.freeze(user, 0 * ONE_TOKEN);
        assertEq(token.frozen(user), 0);
        assertEq(token.availableBalance(user), 10 * ONE_TOKEN);
    }

    function testTransferWhenAmountFrozen() public {
        _setEsu(100000 * ONE_TOKEN / 100); // 1000

        vm.prank(minter);
        token.mint(user, uint256(10 * ONE_TOKEN));

        // freeze allowed
        vm.prank(freezer);
        token.freeze(user, 8 * ONE_TOKEN);
        assertEq(token.frozen(user), 8 * ONE_TOKEN);
        assertEq(token.availableBalance(user), 2 * ONE_TOKEN);

        // try to transfer with amount exceeding frozen balance
        vm.expectRevert(
            abi.encodeWithSelector(ERC20FreezableUpgradeable.ERC20InsufficientUnfrozenBalance.selector, user)
        );
        vm.prank(user);
        token.transfer(anon, 3 * ONE_TOKEN);

        // try to transfer with available balance left -> should work
        vm.prank(user);
        token.transfer(anon, 2 * ONE_TOKEN);

        assertEq(token.availableBalance(user), 0 * ONE_TOKEN);
        assertEq(token.availableBalance(anon), 2 * ONE_TOKEN);
    }

    function testCannotFreezeMoreThanAvailable() public {
        _setEsu(100000 * ONE_TOKEN / 100); // 1000

        vm.prank(minter);
        token.mint(user, uint256(10 * ONE_TOKEN));

        // try to freeze more than user has balance
        vm.expectRevert(
            abi.encodeWithSelector(ERC20FreezableUpgradeable.ERC20InsufficientUnfrozenBalance.selector, user)
        );
        vm.prank(freezer);
        token.freeze(user, 11 * ONE_TOKEN);

        assertEq(token.frozen(user), 0 * ONE_TOKEN);
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
        _setEsu(100000 * ONE_TOKEN / 100); // 1000

        vm.prank(minter);
        token.mint(user, uint256(10 * ONE_TOKEN));

        // send some tokens so sending can be tested when user gets blocked
        address receiver = makeAddr("receiver");
        vm.prank(user);
        token.transfer(receiver, 1 * ONE_TOKEN);
        assertEq(token.balanceOf(receiver), 1 * ONE_TOKEN);

        vm.prank(limiter);
        token.blockUser(receiver);
        assertEq(token.blocked(receiver), true);

        // neither sending nor receiving should work, basically receiver should keep 1 as initially sent!

        // receiving
        vm.expectRevert(abi.encodeWithSelector(ERC20BlocklistUpgradeable.ERC20Blocked.selector, receiver));
        vm.prank(user);
        token.transfer(receiver, 1 * ONE_TOKEN);
        assertEq(token.balanceOf(receiver), 1 * ONE_TOKEN, "Tokens should not be received");

        // sending
        vm.expectRevert(abi.encodeWithSelector(ERC20BlocklistUpgradeable.ERC20Blocked.selector, receiver));
        vm.prank(receiver);
        token.transfer(user, 1 * ONE_TOKEN);
        assertEq(token.balanceOf(receiver), 1 * ONE_TOKEN, "Tokens should not be moved");

        vm.prank(limiter);
        token.unblockUser(receiver);
        assertEq(token.blocked(receiver), false);

        // receiving should work again
        vm.prank(user);
        token.transfer(receiver, 1 * ONE_TOKEN);
        assertEq(token.balanceOf(receiver), 2 * ONE_TOKEN);

        // sending should work again
        vm.prank(receiver);
        token.transfer(user, 1 * ONE_TOKEN);
        assertEq(token.balanceOf(receiver), 1 * ONE_TOKEN);
    }

    function testErc20ApproveWhenUserBlocked() public {
        _setEsu(100000 * ONE_TOKEN / 100); // 1000

        vm.prank(minter);
        token.mint(user, uint256(10 * ONE_TOKEN));

        vm.prank(limiter);
        token.blockUser(user);
        assertEq(token.blocked(user), true);

        // user should not be able approve others in case he is blocked
        vm.expectRevert(abi.encodeWithSelector(ERC20BlocklistUpgradeable.ERC20Blocked.selector, user));
        vm.prank(user);
        token.approve(anon, 1 * ONE_TOKEN);
        assertEq(token.allowance(user, anon), 0);

        vm.prank(limiter);
        token.unblockUser(user);
        assertEq(token.blocked(user), false);

        vm.prank(user);
        token.approve(anon, 1 * ONE_TOKEN);
        assertEq(token.allowance(user, anon), 1 * ONE_TOKEN);
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

        role = token.FREEZER_ROLE();
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

        role = token.REDEEMER_ROLE();
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

        bytes32 freezerRole = token.FREEZER_ROLE();
        assertTrue(token.hasRole(freezerRole, freezer));
        vm.prank(admin);
        token.revokeRole(freezerRole, freezer);
        assertFalse(token.hasRole(freezerRole, freezer));

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

        bytes32 redeemerRole = token.REDEEMER_ROLE();
        assertTrue(token.hasRole(redeemerRole, redeemer));
        vm.prank(admin);
        token.revokeRole(redeemerRole, redeemer);
        assertFalse(token.hasRole(redeemerRole, redeemer));
    }
}
