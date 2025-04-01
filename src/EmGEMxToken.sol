// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20FreezableUpgradeable} from "./ERC20FreezableUpgradeable.sol";
import {ERC20BlocklistUpgradeable} from "./ERC20BlocklistUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title EmGEMx token contract
 * @dev Upgradable ERC 20 contract that contains a chain switch due to the fact that certain functionality (e.g. token max supply) should be limited to the parent chain (Avalanche C-Chain).
 */
contract EmGEMxToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    ERC20FreezableUpgradeable,
    ERC20BlocklistUpgradeable,
    ERC20PermitUpgradeable
{
    ///////////////////
    // Errors
    ///////////////////
    error EmGEMxToken__NotEnoughReserve();
    error EmGEMxToken__InvalidAddress(address sender);
    error EmGEMxToken__RedeemAddressNotSet();
    error EmGEMxToken__BurnOnParentChainNotAllowed();
    error EmGEMxToken__ParentChainOnly();

    ///////////////////
    // Types
    ///////////////////
    AggregatorV3Interface private oracle;

    ///////////////////
    // State Variables
    ///////////////////
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); // token minting/burning
    bytes32 public constant ESU_PER_TOKEN_MODIFIER_ROLE = keccak256("ESU_PER_TOKEN_MODIFIER_ROLE"); // allowed to update esu-per-token parameter
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE"); // pause/unpause token
    bytes32 public constant FREEZER_ROLE = keccak256("FREEZER_ROLE"); // freeze/unfreeze tokens
    bytes32 public constant LIMITER_ROLE = keccak256("LIMITER_ROLE"); // block/unblock user
    bytes32 public constant REDEEMER_ROLE = keccak256("REDEEMER_ROLE"); // burn tokens from redeem address

    /// @dev Controls whether minting restriction is active (on parent chain) or not (on any other chain).
    uint256 public constant PARENT_CHAIN_ID = 43114; // Avalanche C-Chain

    /// @notice Address where users send the funds to in case they want to redeem their tokens for gems.
    /// @dev Tokens are burnt from this address as part of the redeem process which in large part takes place off-chain.
    address private redeemAddress;

    /*
    ESU Calculation:
    - ESU value is written by chainlink
    - Token has an esu_per_token value (set by emgemx)
    - esu_per_token value is updated every month
    - max_tokens = esu / esu_per_token
    */

    // initial esuPerToken: 0.01
    uint256 private esuPerTokenValue = 1;
    uint256 private esuPerTokenPrecision = 100;

    ///////////////////
    // Events
    ///////////////////

    /// @notice Emitted in case the EsuPerToken value was updated by the ESU_PER_TOKEN_MODIFIER_ROLE
    event EsuPerTokenChanged(uint256 value, uint256 precision);
    /// @notice Emitted in case the oracle address was updated by the token admin.
    event OracleAddressChanged(address oldAddres, address newAddress);
    /// @notice Emitted in case the redeem address was updated by the token admin.
    event RedeemAddressChanged(address oldAddress, address newAddress);

    /// @dev Allows to restrict certain functions with core logic to be executed only on the parent chain
    modifier onlyParentChain() {
        if (block.chainid != PARENT_CHAIN_ID) {
            revert EmGEMxToken__ParentChainOnly();
        }
        _;
    }

    ///////////////////
    // Functions
    ///////////////////

    function initialize(address oracleAddres, string memory name, string memory symbol) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __Ownable_init(_msgSender());
        __ERC20Permit_init(name);
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ESU_PER_TOKEN_MODIFIER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(FREEZER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(LIMITER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(REDEEMER_ROLE, DEFAULT_ADMIN_ROLE);

        oracle = AggregatorV3Interface(oracleAddres);
    }

    ///////////////////
    // External Functions
    ///////////////////

    /// @notice Wrapps ERC20BurnableUpgradeable._mint
    function mint(address account, uint256 value) external onlyRole(MINTER_ROLE) {
        _mint(account, value);
    }

    /// @notice Wrapps ERC20BurnableUpgradeable._burn
    function burn(address account, uint256 value) external onlyRole(MINTER_ROLE) {
        _burn(account, value);
    }

    /// @notice Burns token from the redeemAddress.
    /// @dev Only allowed to be called by a dedicated redeemer account. Supposed to be called only on parent chain.
    function redeem(uint256 value) external onlyRole(REDEEMER_ROLE) onlyParentChain {
        if (redeemAddress == address(0)) {
            revert EmGEMxToken__RedeemAddressNotSet();
        }

        _burn(redeemAddress, value);
    }

    /// @notice Wrapps ERC20PausableUpgradeable._pause
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Wrapps ERC20PausableUpgradeable._unpause
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Wrapps ERC20BlocklistUpgradeable._blockUser
    function blockUser(address user) external onlyRole(LIMITER_ROLE) {
        _blockUser(user);
    }

    /// @notice Wrapps ERC20BlocklistUpgradeable._unblockUser
    function unblockUser(address user) external onlyRole(LIMITER_ROLE) {
        _unblockUser(user);
    }

    /// @notice Returns the address of the chainlink PoR oracle for the ESU.
    /// @return The address of the chainlink oracle contract.
    function getOracleAddress() external view returns (address) {
        return address(oracle);
    }

    /// @notice Allows admin to update the chainlink oracle contract address.
    function setOracleAddress(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) onlyParentChain {
        validateNotZeroAddress(newAddress);

        emit OracleAddressChanged(address(oracle), newAddress);
        oracle = AggregatorV3Interface(newAddress);
    }

    /// @notice Returns the redeem address from where the tokens are burnt by the redeemer.
    function getRedeemAddress() external view returns (address) {
        return redeemAddress;
    }

    /// @notice Allows admin to update the redeem address.
    function setRedeemAddress(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) onlyParentChain {
        validateNotZeroAddress(newAddress);

        emit RedeemAddressChanged(redeemAddress, newAddress);
        redeemAddress = newAddress;
    }

    /// @notice Returns the current EsuPerToken value and precision.
    function getEsuPerToken() external view returns (uint256, uint256) {
        return (esuPerTokenValue, esuPerTokenPrecision);
    }

    /// @notice Allows the EsuPerToken modifier to update the value and precision.
    function setEsuPerToken(uint256 value, uint256 precision)
        external
        onlyRole(ESU_PER_TOKEN_MODIFIER_ROLE)
        onlyParentChain
    {
        esuPerTokenValue = value;
        esuPerTokenPrecision = precision;
        emit EsuPerTokenChanged(value, precision);
    }

    /// @inheritdoc ERC20Upgradeable
    function decimals() public pure override returns (uint8) {
        return 8;
    }

    /// @notice Returns the current possible token max supply based on the ESU from oracle and the esuPerToken value.
    /// @dev The max supply is only restricted on the parent chain (Avalanche C-Chain). On all other chains there is no restriction -> the minting/burning is controlled cia CCIP messages.
    /// @return The calculated max supply of the token.
    function getMaxSupply() public view returns (uint256) {
        // no max supply restriction on child chains
        if (block.chainid != PARENT_CHAIN_ID) {
            return type(uint256).max;
        }

        return _getEsuFromOracle() * esuPerTokenPrecision / esuPerTokenValue;
    }

    ///////////////////
    // Internal Functions
    ///////////////////

    /// @notice Contains the custom logic for max token supply restriction and burn restricted to redeemAddress only.
    /// @dev Both max token supply + burn restriction are only validated/active on parent chain.
    /// @inheritdoc	ERC20Upgradeable
    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20FreezableUpgradeable, ERC20BlocklistUpgradeable)
    {
        if (block.chainid == PARENT_CHAIN_ID) {
            // make sure it cannot be minted more than proof of reserve! Only to be checked on parent source chain
            // Code is located here (and not in mint()) so that the logic it is always checked - even if _mint is called from any place)
            if (from == address(0) && totalSupply() + amount > getMaxSupply()) {
                revert EmGEMxToken__NotEnoughReserve();
            }

            // burn on parent chain should be only possible from redeemAddress
            if (to == address(0) && from != redeemAddress) {
                revert EmGEMxToken__BurnOnParentChainNotAllowed();
            }
        }

        super._update(from, to, amount);
    }

    /// @inheritdoc	ERC20Upgradeable
    function _approve(address owner, address spender, uint256 value, bool emitEvent)
        internal
        override(ERC20Upgradeable, ERC20BlocklistUpgradeable)
    {
        super._approve(owner, spender, value, emitEvent);
    }

    ///////////////////
    // Private Functions
    ///////////////////

    /// @notice Queries and returns the chainlink PoR oracle for the ESU value.
    /// @dev This function can only be called on parent chain as on other chains no oracle contracts will be available.
    /// @return The quried ESU value from the chainlink PoR oracle.
    function _getEsuFromOracle() private view returns (uint256) {
        (
            /* uint80 roundID */
            ,
            int256 answer,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = oracle.latestRoundData();

        return uint256(answer);
    }

    //////////////////////////////
    // Private & Internal View & Pure Functions
    //////////////////////////////

    /// @inheritdoc	ERC20FreezableUpgradeable
    function _isFreezer(address user) internal view override returns (bool) {
        return hasRole(FREEZER_ROLE, user);
    }

    function validateNotZeroAddress(address addressToVerify) private pure {
        if (addressToVerify == address(0)) {
            revert EmGEMxToken__InvalidAddress(addressToVerify);
        }
    }
}
