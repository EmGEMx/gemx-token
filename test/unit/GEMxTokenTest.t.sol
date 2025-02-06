// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//import {Test} from "forge-std/Test.sol";
import {Test, console} from "lib/forge-std/src/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {GEMxToken} from "../../src/GEMxToken.sol";
import {DeployToken} from "../../script/DeployToken.s.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract GEMxTokenTest is Test {
    GEMxToken private token;
    MockV3Aggregator private oracle;
    address admin = address(0x1);
    address minter = address(0x2);
    address user = address(0x3);
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
        vm.stopPrank();
    }

    function _setProofOfReserve(int256 value) private {
        oracle.updateAnswer(value);
    }

    function testMintRespectsProofOfReserve() public {
        int256 reserve = 1_000 ether;
        _setProofOfReserve(reserve);

        vm.startPrank(minter);
        token.mint(user, 500 ether);
        assertEq(token.totalSupply(), 500 ether);

        // vm.prank(minter);
        token.mint(user, 500 ether);
        assertEq(token.totalSupply(), 1_000 ether);

        vm.expectRevert(GEMxToken.NotEnoughReserve.selector);
        // vm.prank(minter);
        token.mint(user, 1);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 1_000 ether);
    }

    function testOnlyMinterCanMint() public {
        _setProofOfReserve(1_000 ether);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.MINTER_ROLE())
        );
        vm.prank(user);
        token.mint(user, 1_000 ether);

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

    function testAdminCanGrantRoles() public {
        address newMinter = address(0x5);

        bytes32 role = token.MINTER_ROLE();
        vm.prank(admin);
        token.grantRole(role, newMinter);

        assertTrue(token.hasRole(token.MINTER_ROLE(), newMinter));
    }

    function testRevokeRoles() public {
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));

        bytes32 role = token.MINTER_ROLE();
        vm.prank(admin);
        token.revokeRole(role, minter);

        assertFalse(token.hasRole(token.MINTER_ROLE(), minter));
    }
}
