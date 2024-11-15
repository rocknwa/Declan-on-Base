// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Declan} from "../src/Declan.sol"; // Update the import path as necessary

contract DeclanScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        
        // Deploy the TransportDApp contract
        Declan declan = new Declan();

        console.log("Declan deployed at:", address(declan));

        vm.stopBroadcast();
    }
}
