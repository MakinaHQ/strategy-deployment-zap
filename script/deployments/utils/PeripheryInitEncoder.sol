// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonBase} from "forge-std/Base.sol";

import {IWatermarkFeeManager} from "@makina-periphery/interfaces/IWatermarkFeeManager.sol";

/// @dev Encodes periphery-module `initialize` data from implementation-agnostic JSON config, keyed by `implemId`.
abstract contract PeripheryInitEncoder is CommonBase {
    // Periphery implementation IDs, as described in makina-periphery/SPECIFICATIONS.md
    uint16 internal constant DIRECT_DEPOSITOR_IMPLEM_ID = 1001;
    uint16 internal constant ASYNC_REDEEMER_IMPLEM_ID = 2001;
    uint16 internal constant ASYNC_REDEEMER_FEE_IMPLEM_ID = 2002;
    uint16 internal constant WATERMARK_FEE_MANAGER_IMPLEM_ID = 3001;

    error UnsupportedDepositorImplemId(uint16 implemId);
    error UnsupportedRedeemerImplemId(uint16 implemId);
    error UnsupportedFeeManagerImplemId(uint16 implemId);

    struct DirectDepositorInitParams {
        bool whitelist;
        bool sanctionsCheck;
    }

    struct AsyncRedeemerInitParams {
        uint256 finalizationDelay;
        uint256 minRedeemAmount;
        bool whitelist;
        bool sanctionsCheck;
    }

    struct AsyncRedeemerFeeInitParams {
        uint256 finalizationDelay;
        uint256 minRedeemAmount;
        bool whitelist;
        bool sanctionsCheck;
        uint256 redeemFeeRate;
        uint256 maxRedeemFeeRate;
    }

    /// @dev Reads a depositor config file and returns its `implemId` and ABI-encoded init data.
    function encodeDepositorInitData(string memory json) internal pure returns (uint16 implemId, bytes memory data) {
        implemId = uint16(vm.parseJsonUint(json, ".implemId"));
        if (implemId == DIRECT_DEPOSITOR_IMPLEM_ID) {
            return (implemId, _encodeDirectDepositor(json));
        }
        revert UnsupportedDepositorImplemId(implemId);
    }

    /// @dev Reads a redeemer config file and returns its `implemId` and ABI-encoded init data.
    function encodeRedeemerInitData(string memory json) internal pure returns (uint16 implemId, bytes memory data) {
        implemId = uint16(vm.parseJsonUint(json, ".implemId"));
        if (implemId == ASYNC_REDEEMER_IMPLEM_ID) {
            return (implemId, _encodeAsyncRedeemer(json));
        }
        if (implemId == ASYNC_REDEEMER_FEE_IMPLEM_ID) {
            return (implemId, _encodeAsyncRedeemerFee(json));
        }
        revert UnsupportedRedeemerImplemId(implemId);
    }

    /// @dev Reads a fee-manager config file and returns its `implemId` and ABI-encoded init data.
    function encodeFeeManagerInitData(string memory json) internal pure returns (uint16 implemId, bytes memory data) {
        implemId = uint16(vm.parseJsonUint(json, ".implemId"));
        if (implemId == WATERMARK_FEE_MANAGER_IMPLEM_ID) {
            return (implemId, _encodeWatermarkFeeManager(json));
        }
        revert UnsupportedFeeManagerImplemId(implemId);
    }

    function _encodeDirectDepositor(string memory json) private pure returns (bytes memory) {
        return abi.encode(
            DirectDepositorInitParams({
                whitelist: vm.parseJsonBool(json, ".whitelist"),
                sanctionsCheck: vm.parseJsonBool(json, ".sanctionsCheck")
            })
        );
    }

    function _encodeAsyncRedeemer(string memory json) private pure returns (bytes memory) {
        return abi.encode(
            AsyncRedeemerInitParams({
                finalizationDelay: vm.parseJsonUint(json, ".finalizationDelay"),
                minRedeemAmount: vm.parseJsonUint(json, ".minRedeemAmount"),
                whitelist: vm.parseJsonBool(json, ".whitelist"),
                sanctionsCheck: vm.parseJsonBool(json, ".sanctionsCheck")
            })
        );
    }

    function _encodeAsyncRedeemerFee(string memory json) private pure returns (bytes memory) {
        return abi.encode(
            AsyncRedeemerFeeInitParams({
                finalizationDelay: vm.parseJsonUint(json, ".finalizationDelay"),
                minRedeemAmount: vm.parseJsonUint(json, ".minRedeemAmount"),
                whitelist: vm.parseJsonBool(json, ".whitelist"),
                sanctionsCheck: vm.parseJsonBool(json, ".sanctionsCheck"),
                redeemFeeRate: vm.parseJsonUint(json, ".redeemFeeRate"),
                maxRedeemFeeRate: vm.parseJsonUint(json, ".maxRedeemFeeRate")
            })
        );
    }

    function _encodeWatermarkFeeManager(string memory json) private pure returns (bytes memory) {
        return abi.encode(
            IWatermarkFeeManager.WatermarkFeeManagerInitParams({
                initialMgmtFeeRatePerSecond: vm.parseJsonUint(json, ".mgmtFeeRatePerSecond"),
                initialSmFeeRatePerSecond: vm.parseJsonUint(json, ".smFeeRatePerSecond"),
                initialPerfFeeRate: vm.parseJsonUint(json, ".perfFeeRate"),
                initialMgmtFeeReceivers: vm.parseJsonAddressArray(json, ".mgmtFeeReceivers"),
                initialMgmtFeeSplitBps: vm.parseJsonUintArray(json, ".mgmtFeeSplitBps"),
                initialPerfFeeReceivers: vm.parseJsonAddressArray(json, ".perfFeeReceivers"),
                initialPerfFeeSplitBps: vm.parseJsonUintArray(json, ".perfFeeSplitBps")
            })
        );
    }
}
