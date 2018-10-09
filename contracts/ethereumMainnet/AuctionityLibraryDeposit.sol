pragma solidity ^0.4.24;

/**
 * @title AuctionityDepositLibrary
 * @dev Library for deposit auctionity
 */

import "./AuctionityLibraryDecodeRawTx.sol";

library AuctionityLibraryDeposit{

    function sendTransfer(address _tokenContractAddress, bytes memory _transfer, uint _offset) internal returns (bool){

        if(!isContract(_tokenContractAddress)){
            return false;
        }

        uint8 _numberOfTransfer = uint8(_transfer[_offset]);

        _offset += 1;

        bool _success;
        for (uint8 i = 0; i < _numberOfTransfer; i++){
            (_offset,_success) = decodeTransferCall(_tokenContractAddress, _transfer,_offset);
            
            if(!_success) {
                return false;
            }
        }

        return true;

    }

    function decodeTransferCall(address _tokenContractAddress, bytes memory _transfer, uint _offset) internal returns (uint, bool) {


        bytes memory _sizeOfCallBytes;
        bytes memory _callData;

        uint _sizeOfCallUint;

        if(_transfer[_offset] == 0xb8) {
            _sizeOfCallBytes = new bytes(1);
            _sizeOfCallBytes[0] = bytes1(_transfer[_offset + 1]);

            _offset+=2;
        }
        if(_transfer[_offset] == 0xb9) {

            _sizeOfCallBytes = new bytes(2);
            _sizeOfCallBytes[0] = bytes1(_transfer[_offset + 1]);
            _sizeOfCallBytes[1] = bytes1(_transfer[_offset + 2]);
            _offset+=3;
        }

        _sizeOfCallUint = bytesToUint(_sizeOfCallBytes);

        _callData = new bytes(_sizeOfCallUint);
        for (uint j = 0; j < _sizeOfCallUint; j++) {
            _callData[j] = _transfer[(j + _offset)];
        }

        _offset+=_sizeOfCallUint;

        return (_offset, sendCallData(_tokenContractAddress, _sizeOfCallUint, _callData));


    }

    function sendCallData(address _tokenContractAddress, uint _sizeOfCallUint, bytes memory _callData) internal returns (bool) {

        bool _success;
        bytes4 sig;

        assembly {

            let _ptr := mload(0x40)
            sig := mload(add(_callData,0x20))

            mstore(_ptr,sig) //Place signature at begining of empty storage
            for { let i := 0x04 } lt(i, _sizeOfCallUint) { i := add(i, 0x20) } {
                mstore(add(_ptr,i),mload(add(_callData,add(0x20,i)))) //Add each param
            }


            _success := call(      //This is the critical change (Pop the top stack value)
            sub (gas, 10000), // gas
            _tokenContractAddress, //To addr
            0,    //No value
            _ptr,    //Inputs are stored at location _ptr
            _sizeOfCallUint, //Inputs _size
            _ptr,    //Store output over input (saves space)
            0x20) //Outputs are 32 bytes long

        }

        return _success;
    }

    
    function isContract(address _contractAddress) internal view returns (bool) {
        uint _size;
        assembly { _size := extcodesize(_contractAddress) }
        return _size > 0;
    }

    function bytesToUint(bytes b) internal pure returns (uint256){
        uint256 _number;
        for(uint i=0;i<b.length;i++){
            _number = _number + uint(b[i])*(2**(8*(b.length-(i+1))));
        }
        return _number;
    }

}


