// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract VersionV1Plus {
    // Function to get the version number
    function getVersion() public pure virtual returns (string memory) {
        return "1.1.0";
    }
}
