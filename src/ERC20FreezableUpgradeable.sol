// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/**
 * @dev Extension of {ERC20Upgradeable} that allows to implement a custodian
 * mechanism that can be managed by an authorized account with the
 * {freeze} function.
 *
 * This mechanism allows a custodian (e.g. a DAO or a
 * well-configured multisig) to freeze and unfreeze the balance
 * of a user.
 *
 * The frozen balance is not available for transfers or approvals
 * to other entities to operate on its behalf if. The frozen balance
 * can be reduced by calling {freeze} again with a lower amount.
 *
 * Taken from https://docs.openzeppelin.com/community-contracts/0.0.1/api/token#ERC20Custodian
 */
abstract contract ERC20FreezableUpgradeable is ERC20Upgradeable {
    /// @custom:storage-location erc7201:ERC20FreezableUpgradeable.storage
    struct ERC20FreezableUpgradeableStorage {
        /**
         * @dev The amount of tokens frozen by user address.
         */
        mapping(address user => uint256 amount) _frozen;
    }

    // keccak256(abi.encode(uint256(keccak256("ERC20FreezableUpgradeable.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20FreezableUpgradeableStorageLocation =
        0x3fa3c15e60cd35140c36fb837aa364f49ac6961def966d04c318a640c7984100;

    function _getERC20FreezableStorage() private pure returns (ERC20FreezableUpgradeableStorage storage $) {
        assembly {
            $.slot := ERC20FreezableUpgradeableStorageLocation
        }
    }

    /**
     * @dev Emitted when tokens are frozen for a user.
     * @param user The address of the user whose tokens were frozen.
     * @param amount The amount of tokens that were frozen.
     */
    event TokensFrozen(address indexed user, uint256 amount);

    /**
     * @dev Emitted when tokens are unfrozen for a user.
     * @param user The address of the user whose tokens were unfrozen.
     * @param amount The amount of tokens that were unfrozen.
     */
    event TokensUnfrozen(address indexed user, uint256 amount);

    /**
     * @dev The operation failed because the user has insufficient unfrozen balance.
     */
    error ERC20InsufficientUnfrozenBalance(address user);

    /**
     * @dev The operation failed because the user has insufficient frozen balance.
     */
    error ERC20InsufficientFrozenBalance(address user);

    /**
     * @dev Error thrown when a non-freezer account attempts to perform the freezer operation.
     */
    error ERC20NotFreezer();

    /**
     * @dev Modifier to restrict access to freezer accounts only.
     */
    modifier onlyFreezer() {
        if (!_isFreezer(_msgSender())) revert ERC20NotFreezer();
        _;
    }

    /**
     * @dev Returns the amount of tokens frozen for a user.
     */
    function frozen(address user) public view virtual returns (uint256) {
        ERC20FreezableUpgradeableStorage storage $ = _getERC20FreezableStorage();
        return $._frozen[user];
    }

    /**
     * @dev Adjusts the amount of tokens frozen for a user.
     * @param user The address of the user whose tokens to freeze.
     * @param amount The amount of tokens frozen.
     *
     * Requirements:
     *
     * - The user must have sufficient unfrozen balance.
     */
    function freeze(address user, uint256 amount) external virtual onlyFreezer {
        if (availableBalance(user) < amount) revert ERC20InsufficientUnfrozenBalance(user);
        ERC20FreezableUpgradeableStorage storage $ = _getERC20FreezableStorage();
        $._frozen[user] = amount;
        emit TokensFrozen(user, amount);
    }

    /**
     * @dev Returns the available (unfrozen) balance of an account.
     * @param account The address to query the available balance of.
     * @return available The amount of tokens available for transfer.
     */
    function availableBalance(address account) public view returns (uint256 available) {
        available = balanceOf(account) - frozen(account);
    }

    /**
     * @dev Checks if the user is a freezer.
     * @param user The address of the user to check.
     * @return True if the user is authorized, false otherwise.
     */
    function _isFreezer(address user) internal view virtual returns (bool);

    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0) && availableBalance(from) < value) revert ERC20InsufficientUnfrozenBalance(from);
        super._update(from, to, value);
    }
}
