// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//import {Test} from "forge-std/Test.sol";
import {Test, console} from "lib/forge-std/src/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {GEMxToken} from "../src/GEMxToken.sol";
import {GEMxTokenDeployer} from "../script/GEMxTokenDeployer.s.sol";
import {SolvencyOracleMock} from "../src/SolvencyOracleMock.sol";
import {SolvencyOracleMockDeployer} from "../script/SolvencyOracleMockDeployer.s.sol";

contract GEMxTokenTest is Test {
    GEMxToken private token;
    SolvencyOracleMock private oracle;
    address admin = address(0x1);
    address minter = address(0x2);
    address user = address(0x3);

    function setUp() public {
        admin = makeAddr("Admin");

        //vm.startPrank(admin);
        SolvencyOracleMockDeployer oracleDeployer = new SolvencyOracleMockDeployer();
        oracle = oracleDeployer.run();

        GEMxTokenDeployer deployer = new GEMxTokenDeployer();
        token = deployer.run(address(oracle));

        // Grant roles
        token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        //vm.stopPrank();
    }

    function testMintRespectsProofOfSolvency() public {
        uint256 proof = 1_000 ether;
        _setProofOfSolvency(proof);

        vm.prank(minter);
        token.mint(admin, 500 ether);
        assertEq(token.totalSupply(), 500 ether);

        vm.prank(minter);
        token.mint(admin, 500 ether);
        assertEq(token.totalSupply(), 1_000 ether);

        vm.expectRevert(GEMxToken.NotEnoughReserve.selector);
        vm.prank(minter);
        token.mint(admin, 1);
    }

    function testBurn() public {
        uint256 proof = 1_000 ether;
        _setProofOfSolvency(proof);

        vm.prank(minter);
        token.mint(user, proof);

        vm.prank(user);
        token.burn(500 ether);

        assertEq(token.balanceOf(user), 500 ether);
        assertEq(token.totalSupply(), 500 ether);
    }

    function testOnlyMinterCanMint() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.MINTER_ROLE())
        );
        vm.prank(user);
        token.mint(user, 1_000 ether);
    }

    function testOnlyMinterCanBurn() public {
        uint256 proof = 1_000 ether;
        _setProofOfSolvency(proof);

        vm.prank(minter);
        token.mint(user, proof);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.MINTER_ROLE())
        );
        vm.prank(user);
        token.burn(user, 500 ether);
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

    function _setProofOfSolvency(uint256 proof) private {
        oracle.setProofOfSolvency(proof);
        assertEq(oracle.getProofOfSolvency(), proof);
    }
}
