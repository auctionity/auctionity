pragma solidity ^0.4.24;

/**
 * @title AuctionityLibraryDecodeRawTx
 * @dev Library for auctionity
 */

import "./AuctionityLibraryDecodeRawTx.sol";
import "./RLPReader.sol";
import "./RLPWriter.sol";



contract AuctionityDecodeRawTxTransferNft {

    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    function decodeRawTxGetTransferInfo(bytes memory _signedRawTxTokenTransfer, uint8 _chainId, bytes32 _tokenContractAddressLink) public pure returns (address _tokenContractAddress, address addressOriginalOwnerOfErc721, address addressDeposit, uint tokenId) {

        bytes memory _tokenTransferData;
        RLPReader.RLPItem[] memory _signedRawTxTokenTransferRLPItem = _signedRawTxTokenTransfer.toRlpItem().toList();

        _tokenContractAddress = _signedRawTxTokenTransferRLPItem[3].toAddress();
        _tokenTransferData = _signedRawTxTokenTransferRLPItem[5].toBytes();

        (addressOriginalOwnerOfErc721, addressDeposit, tokenId) = decodeRawTxGetTransferInfoData(_signedRawTxTokenTransferRLPItem, _chainId, _tokenContractAddressLink, _tokenTransferData);

    }

    function decodeRawTxGetTransferInfoData(RLPReader.RLPItem[] memory _signedRawTxTokenTransferRLPItem, uint8 _chainId, bytes32 _tokenContractAddressLink, bytes memory _tokenTransferData) internal pure returns (address addressOriginalOwnerOfErc721, address addressDeposit, uint tokenId){

        bytes4 selector;
        assembly { selector := mload(add(_tokenTransferData,0x20))}

        if(_tokenContractAddressLink == 0x73ad2146b3d3a286642c794379d750360a2d53a3459a11b3e5d6cc900f55f44a) { // keccak256('ERC721')

            // 0x23b872dd : bytes4(keccak256('transferFrom(address,address,uint256)'))
            // 0x42842e0e : bytes4(keccak256('safeTransferFrom(address,address,uint256)'))
            // 0xb88d4fde : bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)'))
            if(selector == 0x23b872dd ||
            selector == 0x42842e0e ||
            selector == 0xb88d4fde ) {
                assembly {
                    addressOriginalOwnerOfErc721 := mload(add(_tokenTransferData,add(4,0x20)))
                    addressDeposit := mload(add(_tokenTransferData,add(36,0x20)))
                    tokenId := mload(add(_tokenTransferData,add(68,0x20)))
                }
                return;
            }
        }
        else if(_tokenContractAddressLink == 0xc13b881b7ab0310915e32767fd83683d3c5150c07e8da093f99668a8f0d0e463) { // keccak256('CryptoKitties')

            // 0x23b872dd : bytes4(keccak256('transferFrom(address,address,uint256)'))
            if(selector == 0x23b872dd) {
                assembly {
                    addressOriginalOwnerOfErc721 := mload(add(_tokenTransferData,add(4,0x20)))
                    addressDeposit := mload(add(_tokenTransferData,add(36,0x20)))
                    tokenId := mload(add(_tokenTransferData,add(68,0x20)))
                }
                return;
            }

            // 0xa9059cbb : bytes4(keccak256('transfer(address,uint256)'))
            if(selector == 0xa9059cbb){
                addressOriginalOwnerOfErc721 = AuctionityLibraryDecodeRawTx.getSignerFromSignedRawTxRLPItemp(_signedRawTxTokenTransferRLPItem,_chainId);
                assembly {
                    addressDeposit := mload(add(_tokenTransferData,add(4,0x20)))
                    tokenId := mload(add(_tokenTransferData,add(36,0x20)))
                }
                return;
            }
        }
        else if(_tokenContractAddressLink == 0x7dd83c8d6517ff6bd0629cce1301829845e8944642023c9fd7f0e8e5963acbac) { // keccak256('Etheremon')

            // 0x23b872dd : bytes4(keccak256('transferFrom(address,address,uint256)'))
            // 0x42842e0e : bytes4(keccak256('safeTransferFrom(address,address,uint256)'))
            // 0xb88d4fde : bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)'))
            if(selector == 0x23b872dd ||
            selector == 0x42842e0e ||
            selector == 0xb88d4fde ) {
                assembly {
                    addressOriginalOwnerOfErc721 := mload(add(_tokenTransferData,add(4,0x20)))
                    addressDeposit := mload(add(_tokenTransferData,add(36,0x20)))
                    tokenId := mload(add(_tokenTransferData,add(68,0x20)))
                }
                return;
            }

            // 0xa9059cbb : bytes4(keccak256('transfer(address,uint256)'))
            if(selector == 0xa9059cbb){
                addressOriginalOwnerOfErc721 = AuctionityLibraryDecodeRawTx.getSignerFromSignedRawTxRLPItemp(_signedRawTxTokenTransferRLPItem,_chainId);
                assembly {
                    addressDeposit := mload(add(_tokenTransferData,add(4,0x20)))
                    tokenId := mload(add(_tokenTransferData,add(36,0x20)))
                }
                return;

            }

        }

    }




}
