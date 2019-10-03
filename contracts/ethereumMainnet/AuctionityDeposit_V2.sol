pragma solidity ^0.5.4;

import "./AuctionityStorage1.sol";

import "../CommonContract/SafeMath.sol";
import "../CommonContract/AuctionityLibrary_V1.sol";
import "../CommonContract/AuctionityLibraryDecodeRawTx_V1.sol";

import "../CommonContract/AuctionityChainId_V1.sol";
import "../CommonContract/AuctionityOracable_V1.sol";
import "../CommonContract/AuctionityPausable_V1.sol";

contract AuctionityDeposit_V2 is AuctionityStorage1, AuctionityLibrary_V1, AuctionityChainId_V1 {
    using SafeMath for uint256;

    // events
    event LogAddDepot_V2(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount
    );

    event LogAddBatchDepot_V2(
        address user,
        address tokenContractAddress,
        uint256[] tokenId,
        uint256[] amount
    );

    event LogWithdrawalVoucherSubmitted_V2(
        bytes32 withdrawalVoucherHash
    );

    /// @notice fallback payable function , with revert if is deactivated
    function() external payable {
        require(!delegatedSendGetPaused_V1(), "Contract is in paused");
        require(msg.value > 0, "Value must be greater than 0");

        emit LogAddDepot_V2(
            msg.sender,
            address(0),
            0,
            msg.value
        );
    }

    /**
     * @notice Handle the receipt of an NFT
     * @dev The ERC721 smart contract calls this function on the recipient
     * after a `safeTransfer`. This function MUST return the function selector,
     * otherwise the caller will revert the transaction. The selector to be
     * returned can be obtained as `this.onERC721Received.selector`. This
     * function MAY throw to revert and reject the transfer.
     * Note: the ERC721 contract address is always the message sender.
     * @param _user The address which called `safeTransferFrom` function
     * @param _previousOwner The address which previously owned the token
     * @param _tokenId The NFT identifier which is being transferred
     * @param _data Additional data with no specified format
     * @return bytes4 `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
     */
    function onERC721Received(address _user, address _previousOwner, uint256 _tokenId, bytes memory _data)
        public returns (bytes4) {
        
        emit LogAddDepot_V2(
            _user,
            msg.sender,
            _tokenId,
            1
        );

        return 0x150b7a02;

    }


    /**
    @notice Handle the receipt of a single ERC1155 token type.
    @dev An ERC1155-compliant smart contract MUST call this function on the token recipient contract, at the end of a `safeTransferFrom` after the balance has been updated.
    This function MUST return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` (i.e. 0xf23a6e61) if it accepts the transfer.
    This function MUST revert if it rejects the transfer.
    Return of any other value than the prescribed keccak256 generated value MUST result in the transaction being reverted by the caller.
    @param _operator  The address which initiated the transfer (i.e. msg.sender)
    @param _from      The address which previously owned the token
    @param _id        The ID of the token being transferred
    @param _value     The amount of tokens being transferred
    @param _data      Additional data with no specified format
    @return           `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
*/
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4)
    {

        emit LogAddDepot_V2(
            _from,
            msg.sender,
            _id,
            _value
        );

        return 0xf23a6e61;
    }

    /**
       @notice Handle the receipt of multiple ERC1155 token types.
       @dev An ERC1155-compliant smart contract MUST call this function on the token recipient contract, at the end of a `safeBatchTransferFrom` after the balances have been updated.
       This function MUST return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` (i.e. 0xbc197c81) if it accepts the transfer(s).
       This function MUST revert if it rejects the transfer(s).
       Return of any other value than the prescribed keccak256 generated value MUST result in the transaction being reverted by the caller.
       @param _operator  The address which initiated the batch transfer (i.e. msg.sender)
       @param _from      The address which previously owned the token
       @param _ids       An array containing ids of each token being transferred (order and length must match _values array)
       @param _values    An array containing amounts of each token being transferred (order and length must match _ids array)
       @param _data      Additional data with no specified format
       @return           `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
   */
    function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external returns(bytes4){

        emit LogAddBatchDepot_V2(
            _from,
            msg.sender,
            _ids,
            _values
        );

        return 0xbc197c81;

    }



    /*
     * @notice withdrawal voucher
     * @param _tokenContractAddress address of token contract, address(0) if eth currency
     * @param _withdrawalVoucherHash bytes32 : hash of withdrawal ask from AcNet
     * @param _transferCalldata bytes : data for transfer
     * @param _oracleSignature bytes : RSV from oracle's verification data
     */
    function withdrawalVoucherERC1155_V2(
        address _tokenContractAddress,
        bytes32 _withdrawalVoucherHash,
        bytes memory _transferCalldata,
        bytes memory _oracleSignature
    ) public {
        require(!delegatedSendGetPaused_V1(), "Contract is in paused");

        require(
            withdrawalVoucherSubmitted[_withdrawalVoucherHash] != true,
            "Withdrawal voucher is already submited"
        );

        withdrawalVoucherList.push(_withdrawalVoucherHash);
        withdrawalVoucherSubmitted[_withdrawalVoucherHash] = true;

        require(
            _withdrawalVoucherOracleSignatureVerification_V2(
                _tokenContractAddress,
                _withdrawalVoucherHash,
                keccak256(_transferCalldata),
                _oracleSignature
            ),
            "Withdrawal voucher invalid signature of oracle"
        );

        if (_tokenContractAddress != address(0)) {
            // Transfer of a token managed by a contract
            _sendCallData_V2(_tokenContractAddress,_transferCalldata);
        } else {
            // Transfer of ether (not managed by a contract)
            address payable user;
            uint256 amount;

            assembly {
                user := mload(add(_transferCalldata, 20)) // 32 - (32 - 20)
                amount := mload(add(_transferCalldata, 52))
            }

            require(user.send(amount), "Can't send ethers");
        }

        emit LogWithdrawalVoucherSubmitted_V2(
            _withdrawalVoucherHash
        );
    }

    /* @notice internal function : send call data to a smart contract
     * @param _tokenContractAddress address of token contract, address(0) if eth currency
     * @param _callData bytes : data for transfer
     */
    function _sendCallData_V2(
        address _tokenContractAddress,
        bytes memory _callData
    ) internal {
        bool _success;
        assembly {

            // call external smart contract, return _success
            _success := call(
                gas,
                _tokenContractAddress, //To addr
                0, //No value
                add(_callData,0x20), //Inputs are stored at location _ptr
                mload(_callData), //Inputs _size
                0x40, //Store output over input (saves space)
                0
            ) //Outputs are 32 bytes long

        }
        require(_success, "Can't send token");
    }


    /* @notice internal withdrawal voucher oracle signature verification
     * @param _tokenContractAddress address of token contract, address(0) if eth currency
     * @param _withdrawalVoucherHash bytes32 : hash of withdrawal ask from AcNet
     * @param _transferCalldata bytes : data for transfer
     * @param _oracleSignature bytes : RSV from oracle's verification data
     * @return _success
     */
    function _withdrawalVoucherOracleSignatureVerification_V2(
        address _tokenContractAddress,
        bytes32 _withdrawalVoucherHash,
        bytes32 _transferCalldataHash,
        bytes memory _oracleSignature
    ) internal returns (bool) {
        /// @dev if oracle is the signer of this withdrawal voucher
        return delegatedSendGetOracle_V1(

        ) == AuctionityLibraryDecodeRawTx_V1.ecrecoverSigner_V1(
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(
                        abi.encodePacked(
                            address(this),
                            _tokenContractAddress,
                            _withdrawalVoucherHash,
                            _transferCalldataHash
                        )
                    )
                )
            ),
            _oracleSignature,
            0
        );
    }
}
