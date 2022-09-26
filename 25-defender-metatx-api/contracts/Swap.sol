// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";

/**
 * @author Neet_bear
 */
contract TestSwap is ERC2771Context {
    address public operator;

    uint8 ratioA = 100;
    uint8 ratioB = 100; 
    
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        uint256 time
    );
    event Sync(uint256 reserve0, uint256 reserve1);

    address public immutable token0;
    uint256 public token1Amount;

    modifier onlyOperator() {
        require(operator == _msgSender(), "Error : UNAUTHORIZED");
        _;
    }

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "Error : LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    bytes32 private hashed;
    modifier isHashed(string memory _secretMsg) {
        require(keccak256(abi.encode(_secretMsg)) == hashed, "Error : Wrong Secret Key"); 
        _;
    }

    constructor(
        address _token0,
        string memory _hashed,
        MinimalForwarder forwarder,
        uint256 _token1Amount
    ) ERC2771Context(address(forwarder)) {
        require(isContract(_token0), "Error : Invalid address");
        token0 = _token0;
        hashed = keccak256(abi.encode(_hashed));
        operator = _msgSender();
        token1Amount = _token1Amount;
    }

    function getReserves()
        public
        view
        returns (
            uint256 _reserve0,
            uint256 _reserve1
        )
    {
        _reserve0 = _balanceOf(address(this));
        _reserve1 = token1Amount;
    }

    function _update(
        uint256 balance0,
        uint256 balance1
    ) internal {
        token1Amount = balance1;

        emit Sync(balance0, balance1);
    }

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));
    bytes4 private constant SELECTOR2 = bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));

    function _safeTransfer(
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token0.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Error :  TRANSFER_FAILED");
    }
    function _safeTransferFrom(
        // address from,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token0.call(abi.encodeWithSelector(SELECTOR2, _msgSender(), to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Error :  TRANSFERFROM_FAILED");
    }
    function _balanceOf(
        address _owner
    ) private view returns(uint256){
        return IERC20(token0).balanceOf(_owner);
    }

    function swap(
        uint256 amount0In,
        uint256 amount1In,
        string memory _secretMsg
    ) external lock isHashed(_secretMsg) {
        require(amount0In > 0 || amount1In > 0, "Error :  INSUFFICIENT_OUTPUT_AMOUNT");
        uint256 reserve0 = _balanceOf(address(this));
        uint256 reserve1 = token1Amount;
        uint256 amount0Out;
        uint256 amount1Out;
        
        if(amount1In > 0) {
            amount0Out = amount1In * ratioA / ratioB; // gas fee 차감 
            token1Amount += amount1In;
            _safeTransfer(_msgSender(), amount0Out);
            reserve0 -= amount0Out;
        }
        if(amount0In > 0) {
            amount1Out = amount0In * ratioB / ratioA;
            _safeTransferFrom(address(this), amount0In);
            token1Amount -= amount1Out;
            reserve0 += amount0In;
        }
        require(amount0Out < reserve0 && amount1Out < reserve1, "Error : INSUFFICIENT_LIQUIDITY");
        uint256 balance0 = reserve0;

        _update(balance0, token1Amount);
        emit Swap(_msgSender(), amount0In, amount1In, amount0Out, amount1Out, block.timestamp);
    }

    function withdraw(
        uint256 _token0OutAmount,
        uint256 _token1OutAmount
    ) internal {
        require(_token0OutAmount <= _balanceOf(address(this)) && _token1OutAmount <= token1Amount, "Error :  CheckAmount");
        if(_token0OutAmount > 0) _safeTransfer(address(this), uint256(_token0OutAmount));
        if(_token1OutAmount > 0) token1Amount -= _token1OutAmount;
    }

    function deposit(
        uint256 _tokenIn1Amount
    ) internal {
        if(_tokenIn1Amount > 0) token1Amount += _tokenIn1Amount;
    }

    function changeFee(
        uint8 _ratioA,
        uint8 _ratioB
    ) internal {
        ratioA = _ratioA;
        ratioB = _ratioB;
    }
    
    function manage(
        uint256 _amountAOut,
        uint256 _amountBIn,
        uint256 _amountBOut,
        uint8 _ratioA,
        uint8 _ratioB,
        bytes32 _hashed
    ) external onlyOperator lock {
        withdraw(_amountAOut, _amountBOut);
        token1Amount += _amountBIn;
        changeFee(_ratioA, _ratioB);
        hashed = _hashed;

        _update(_balanceOf(address(this)), token1Amount);
    } 

    function isContract(address _target) internal view returns (bool) {
        if(_target == address(0)) {
            return false;
        }

        uint256 size;
        assembly { size := extcodesize(_target) }
        return size > 0;
    } 
}