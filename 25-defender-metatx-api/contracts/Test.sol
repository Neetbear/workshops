//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";

contract Test is ERC2771Context {
    using SafeERC20 for ERC20;   
    address token;

    constructor(MinimalForwarder forwarder, address _token)
        ERC2771Context(address(forwarder)) {
            token = _token;
    }

    function div(uint _a, uint _b) public pure returns(uint _num) {
        _num = _a / _b; 
    }

    function hashed(string memory _secretMsg) public pure returns(bytes32) {
        return keccak256(abi.encode(_secretMsg));
    }
    // test <-> 0x05294e8f4a5ee627df181a607a6376b9d98fab962d53722cd6871cf8321cedf6

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));
    bytes4 private constant SELECTOR2 = bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));

    function _safeTransfer(
        // address token,
        address to,
        uint256 value
    ) external {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }
    function _safeTransferFrom(
        // address token,
        // address from,
        address to,
        uint256 value
    ) external {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR2, _msgSender(), to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFERFROM_FAILED");
    }
}