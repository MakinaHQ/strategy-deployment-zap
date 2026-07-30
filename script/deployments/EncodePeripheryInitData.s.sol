// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";

import {PeripheryInitEncoder} from "./utils/PeripheryInitEncoder.sol";

/// @dev "Beforehand" step that generates the periphery init data for a Machine deployment.
///      It reads up to three implementation-agnostic config files (one per Machine periphery slot), ABI-encodes
///      each module's init data by dispatching on the `implemId` declared in the file, and writes the resulting
///      `peripheryParams` (implementation IDs + encoded init data) into the machine-creation input file consumed
///      by the Schedule/Create scripts. Run this once, review the produced file, then schedule and execute against
///      it unchanged.
///
///      A slot is skipped (implemId 0, empty init data) when its filename env var is unset or empty.
///
///      Env vars:
///        - DEPOSITOR_INPUT_FILENAME    file in inputs/machine-depositors/     (optional)
///        - REDEEMER_INPUT_FILENAME     file in inputs/machine-redeemers/      (optional)
///        - FEE_MANAGER_INPUT_FILENAME  file in inputs/machine-fee-managers/   (optional)
///        - HUB_STRAT_INPUT_SUBDIR      create-machines | create-machines-from-pre-deposit (default: create-machines)
///        - HUB_STRAT_INPUT_FILENAME    target machine-creation input file to patch (required)
contract EncodePeripheryInitData is Script, PeripheryInitEncoder {
    function run() public {
        string memory inputsBase = string.concat(vm.projectRoot(), "/script/deployments/inputs/");

        uint16 depositorImplemId;
        bytes memory depositorInitData;
        string memory depositorFile = vm.envOr("DEPOSITOR_INPUT_FILENAME", string(""));
        if (bytes(depositorFile).length != 0) {
            (depositorImplemId, depositorInitData) =
                encodeDepositorInitData(vm.readFile(string.concat(inputsBase, "machine-depositors/", depositorFile)));
        }

        uint16 redeemerImplemId;
        bytes memory redeemerInitData;
        string memory redeemerFile = vm.envOr("REDEEMER_INPUT_FILENAME", string(""));
        if (bytes(redeemerFile).length != 0) {
            (redeemerImplemId, redeemerInitData) =
                encodeRedeemerInitData(vm.readFile(string.concat(inputsBase, "machine-redeemers/", redeemerFile)));
        }

        uint16 feeManagerImplemId;
        bytes memory feeManagerInitData;
        string memory feeManagerFile = vm.envOr("FEE_MANAGER_INPUT_FILENAME", string(""));
        if (bytes(feeManagerFile).length != 0) {
            (feeManagerImplemId, feeManagerInitData) = encodeFeeManagerInitData(
                vm.readFile(string.concat(inputsBase, "machine-fee-managers/", feeManagerFile))
            );
        }

        // Serialize the peripheryParams object.
        string memory obj = "peripheryParams";
        vm.serializeUint(obj, "depositorImplemId", depositorImplemId);
        vm.serializeUint(obj, "redeemerImplemId", redeemerImplemId);
        vm.serializeUint(obj, "feeManagerImplemId", feeManagerImplemId);
        vm.serializeBytes(obj, "depositorInitData", depositorInitData);
        vm.serializeBytes(obj, "redeemerInitData", redeemerInitData);
        string memory serialized = vm.serializeBytes(obj, "feeManagerInitData", feeManagerInitData);

        // Patch the peripheryParams node of the machine-creation input file in place.
        string memory subdir = vm.envOr("HUB_STRAT_INPUT_SUBDIR", string("create-machines"));
        string memory machinePath = string.concat(inputsBase, subdir, "/", vm.envString("HUB_STRAT_INPUT_FILENAME"));

        vm.writeJson(serialized, machinePath, ".peripheryParams");
    }
}
