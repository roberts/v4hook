// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {BaseHook} from "v4-periphery/src/BaseHook.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";

/// @notice Custom fee hook: 
/// - NFT holders: 0% fees
/// - Non-holders: 3% buy fee (to buyTreasury), 10% sell fee (to sellTreasury)
/// - Fees are skimmed from swap proceeds, no approvals required
contract CustomFeeHook is BaseHook {
    IERC721 public immutable nft;
    Currency public immutable token; // your ERC-20 as a Currency type
    address public immutable buyTreasury;
    address public immutable sellTreasury;

    constructor(
        IPoolManager _poolManager,
        address _nft,
        Currency _token,
        address _buyTreasury,
        address _sellTreasury
    ) BaseHook(_poolManager) {
        nft = IERC721(_nft);
        token = _token;
        buyTreasury = _buyTreasury;
        sellTreasury = _sellTreasury;
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false
        });
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4) {
        // NFT holders skip fees
        if (nft.balanceOf(sender) > 0) {
            return CustomFeeHook.afterSwap.selector;
        }

        // Assume our ERC-20 is token1 in the pool
        int256 amountToken = delta.amount1();

        if (amountToken > 0) {
            // BUY: trader received token → skim 3% of output
            uint256 fee = (uint256(amountToken) * 3) / 100;
            poolManager.take(token, buyTreasury, fee);
        } else if (amountToken < 0) {
            // SELL: trader gave token → skim 10% of input
            uint256 fee = (uint256(-amountToken) * 10) / 100;
            poolManager.take(token, sellTreasury, fee);
        }

        return CustomFeeHook.afterSwap.selector;
    }
}
