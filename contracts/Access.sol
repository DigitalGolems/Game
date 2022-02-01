// SPDX-License-Identifier: GPL-3.0

pragma experimental ABIEncoderV2;
pragma solidity ^0.8.10;

import "../../Utils/Owner.sol";

contract Access is Owner {
    
    
   /* 
    * @dev Requires msg.sender to have valid access message.
    * @param _v ECDSA signature parameter v.
    * @param _r ECDSA signature parameters r.
    * @param _s ECDSA signature parameters s.
    */
    modifier onlyValidResult(uint8 _v, bytes32 _r, bytes32 _s, uint256 _userToWin) 
    {
        require( isValidAccessMessage(msg.sender, _v,_r,_s, _userToWin), "Not valid");
        _;
    }

    modifier onlyValidSession(
        uint8 _v, 
        bytes32 _r, 
        bytes32 _s,
        uint32[] memory things,
        uint32[] memory resources,
        uint32[] memory augmentations,
        uint8[] memory psychoAmount
        ) 
    {
        require( isValidAccessSession(
            msg.sender, 
            _v,
            _r,
            _s, 
            things,
        resources,
        augmentations,
    psychoAmount), "Not valid");
        _;
    }
    /* 
    * @dev Verifies if message was signed by owner to give access to _add for this contract.
    *      Assumes Geth signature prefix.
    * @param _add Address of agent with access
    * @param _v ECDSA signature parameter v.
    * @param _r ECDSA signature parameters r.
    * @param _s ECDSA signature parameters s.
    * @return Validity of access message for a given address.
    */
    //проверить можно ли вводить доп сообщение в hash
    //чтобы можно было еще и на лотереи использовать
    function isValidAccessMessage(
        address _add,
        uint8 _v, 
        bytes32 _r, 
        bytes32 _s,
        uint256 _userToWin
        ) 
        view public returns (bool)
    {
        bytes32 hash = keccak256(abi.encodePacked(address(this), _add, _userToWin));
        return owner == ecrecover(
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)),
            _v,
            _r,
            _s
        );
    }

    function isValidAccessSession(
        address _add,
        uint8 _v, 
        bytes32 _r, 
        bytes32 _s,
        uint32[] memory _things,
        uint32[] memory _resources,
        uint32[] memory _augmentations,
        uint8[] memory _psychoAmount
        ) 
        view public returns (bool)
    {
        bytes32 hash = keccak256(abi.encodePacked(address(this), _add, _things, _resources, _augmentations, _psychoAmount));
        return owner == ecrecover(
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)),
            _v,
            _r,
            _s
        );
    }

}