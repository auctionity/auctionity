pragma solidity ^0.5.4;

import "./AuctionityStorage0.sol";

/// @title Auction library for delegate for some delegated function
contract AuctionityLibrary_V1 is AuctionityStorage0 {
    /// @notice get delegated addrss from a selector
    /// @param _selector byte4
    /// @return _contractDelegate address
    function getDelegate_V1(bytes4 _selector)
        public
        view
        returns (address _contractDelegate)
    {
        return delegates[_selector];
    }

    /// @notice call delegated function
    /// @param _calldata bytes : data sended to delegated contract
    /// @param _contractFallback address: address of fallback if selector is not exist, address(0) if no fallback
    /// @return uint return pointer and uint return size of callData return
    function _callDelegated_V1(
        bytes memory _calldata,
        address _contractFallback
    ) internal returns (uint returnPtr, uint returnSize) {
        /// @dev get selector from _calldata
        bytes4 _selector;
        assembly {
            _selector := mload(add(_calldata, 0x20))
        }

        /// @dev get address of delegated from selector
        address _contractDelegate = getDelegate_V1(_selector);

        /// @dev if _contractDelegate not found set _contractFallback into _contractFallback
        if (_contractDelegate == address(0)) {
            _contractDelegate = _contractFallback;
        }

        require(
            _contractDelegate != address(0),
            "Auctionity function does not exist."
        );

        /// @dev delegate call and return result, or the eventual revert
        assembly {
            let result := delegatecall(
                gas,
                _contractDelegate,
                add(_calldata, 0x20),
                mload(_calldata),
                0,
                0
            )
            returnSize := returndatasize
            returnPtr := mload(0x40)
            returndatacopy(returnPtr, 0, returnSize)
            if eq(result, 0) {
                revert(returnPtr, returnSize)
            }
        }

        /// @dev return returndatacopy
        return (returnPtr, returnSize);

    }

    /// @notice delegate IsContractOwner_V1
    /// @return  _isContractOwner
    function delegatedSendIsContractOwner_V1()
        public
        returns (bool _isContractOwner)
    {
        uint returnPtr;
        uint returnSize;

        (returnPtr, returnSize) = _callDelegated_V1(
            abi.encodeWithSelector(
                bytes4(keccak256("delegatedReceiveIsContractOwner_V1()"))
            ),
            address(0)
        );

        assembly {
            _isContractOwner := mload(returnPtr)
        }

        return _isContractOwner;
    }

    modifier delegatedSendIsOracle_V1() {
        require(
            msg.sender == delegatedSendGetOracle_V1(),
            "Sender must be oracle"
        );
        _;
    }

    /// @notice delegate getOracle_V1
    /// @return address _oracle
    function delegatedSendGetOracle_V1() public returns (address _oracle) {
        uint returnPtr;
        uint returnSize;

        (returnPtr, returnSize) = _callDelegated_V1(
            abi.encodeWithSelector(
                bytes4(keccak256("delegatedReceiveGetOracle_V1()"))
            ),
            address(0)
        );

        assembly {
            _oracle := mload(returnPtr)
        }
        return _oracle;

    }

    /// @notice delegate getPaused_V1
    /// @return bool _isPaused
    function delegatedSendGetPaused_V1() public returns (bool _isPaused) {
        uint returnPtr;
        uint returnSize;

        (returnPtr, returnSize) = _callDelegated_V1(
            abi.encodeWithSelector(
                bytes4(keccak256("delegatedReceiveGetPaused_V1()"))
            ),
            address(0)
        );
        assembly {
            _isPaused := mload(returnPtr)
        }
        return _isPaused;

    }

    /// @notice delegate lockDeposit_V1
    /// @param _tokenContractAddress address
    /// @param _tokenId uint256
    /// @param _amount uint256
    /// @param _auctionId uint256
    /// @param _refundUser address
    /// @return bool _isPaused
    function delegatedLockDeposit_V1(
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _auctionId,
        address _refundUser
    ) public returns (bool _success) {
        uint returnPtr;
        uint returnSize;

        (returnPtr, returnSize) = _callDelegated_V1(
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "lockDeposit_V1(address,uint256,uint256,uint256,address)"
                    )
                ),
                _tokenContractAddress,
                _tokenId,
                _amount,
                _auctionId,
                _refundUser
            ),
            address(0)
        );

        assembly {
            _success := mload(returnPtr)
        }
        return _success;

    }

    /// @notice verify if _contractAddress is a contract
    /// @param _contractAddress address
    /// @return _isContract
    function isContract_V1(address _contractAddress)
        internal
        view
        returns (bool _isContract)
    {
        uint _size;
        assembly {
            _size := extcodesize(_contractAddress)
        }
        return _size > 0;
    }

    /// @notice cast a bytesmemory into a uint256
    /// @param b bytes
    /// @return uint256
    function bytesToUint_V1(bytes memory b) internal pure returns (uint256) {
        uint256 _number;
        for (uint i = 0; i < b.length; i++) {
            _number = _number + uint8(b[i]) * (2 ** (8 * (b.length - (i + 1))));
        }
        return _number;
    }
}
