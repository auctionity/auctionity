pragma solidity ^0.4.24;

/**
 * @title AuctionityLibraryDecodeRawTx
 * @dev Library for auctionity
 */

import "./RLPReader.sol";
import "./RLPWriter.sol";



library AuctionityLibraryDecodeRawTx {

    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    function decodeRawTxGetBiddingInfo(bytes memory _signedRawTxBidding, uint8 _chainId) internal pure returns (bytes32 _hashRawTxTokenTransfer, address _auctionContractAddress, uint256 _bidAmount, address _signerBid) {

        bytes memory _auctionBidlData;
        RLPReader.RLPItem[] memory _signedRawTxBiddingRLPItem = _signedRawTxBidding.toRlpItem().toList();

        _auctionContractAddress = _signedRawTxBiddingRLPItem[3].toAddress();
        _auctionBidlData = _signedRawTxBiddingRLPItem[5].toBytes();

        bytes4 _selector;
        assembly { _selector := mload(add(_auctionBidlData,0x20))}

        _signerBid = getSignerFromSignedRawTxRLPItemp(_signedRawTxBiddingRLPItem,_chainId);

        // 0x1d03ae68 : bytes4(keccak256('bid(uint256,address,bytes32)'))
        if(_selector == 0x1d03ae68 ) {

            assembly {
                _bidAmount := mload(add(_auctionBidlData,add(4,0x20)))
                _hashRawTxTokenTransfer := mload(add(_auctionBidlData,add(68,0x20)))
            }

        }

    }



    function decodeRawTxGetCreateAuctionInfo(bytes memory _signedRawTxCreateAuction, uint8 _chainId) internal pure returns (
        bytes32 _tokenHash,
        address _auctionFactoryContractAddress,
        address _signerCreate,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint8 _rewardPercent
    ) {

        bytes memory _createAuctionlData;
        RLPReader.RLPItem[] memory _signedRawTxCreateAuctionRLPItem = _signedRawTxCreateAuction.toRlpItem().toList();


        _auctionFactoryContractAddress = _signedRawTxCreateAuctionRLPItem[3].toAddress();
        _createAuctionlData = _signedRawTxCreateAuctionRLPItem[5].toBytes();


        _signerCreate = getSignerFromSignedRawTxRLPItemp(_signedRawTxCreateAuctionRLPItem,_chainId);

        bytes memory _signedRawTxTokenTransfer;

        (_signedRawTxTokenTransfer, _tokenContractAddress,_tokenId,_rewardPercent) = decodeRawTxGetCreateAuctionInfoData( _createAuctionlData);



        _tokenHash = keccak256(_signedRawTxTokenTransfer);

    }

    function decodeRawTxGetCreateAuctionInfoData(bytes memory _createAuctionlData) internal pure returns(
        bytes memory _signedRawTxTokenTransfer,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint8 _rewardPercent
    ) {
        bytes4 _selector;
        assembly { _selector := mload(add(_createAuctionlData,0x20))}

        uint _positionOfSignedRawTxTokenTransfer;
        uint _sizeOfSignedRawTxTokenTransfer;

        // 0xffd6d828 : bytes4(keccak256('create(bytes,address,uint256,bytes,address,uint8)'))
        if(_selector == 0xffd6d828) {

            assembly {
                _positionOfSignedRawTxTokenTransfer := mload(add(_createAuctionlData,add(4,0x20)))
                _sizeOfSignedRawTxTokenTransfer := mload(add(_createAuctionlData,add(add(_positionOfSignedRawTxTokenTransfer,4),0x20)))

            // tokenContractAddress : get 2th param
                _tokenContractAddress := mload(add(_createAuctionlData,add(add(mul(1,32),4),0x20)))
            // tockenId : get 3th param
                _tokenId := mload(add(_createAuctionlData,add(add(mul(2,32),4),0x20)))
            // rewardPercent : get 6th param
                _rewardPercent := mload(add(_createAuctionlData,add(add(mul(5,32),4),0x20)))

            }

            _signedRawTxTokenTransfer = new bytes(_sizeOfSignedRawTxTokenTransfer);

            for (uint i = 0; i < _sizeOfSignedRawTxTokenTransfer; i++) {
                _signedRawTxTokenTransfer[i] = _createAuctionlData[i + _positionOfSignedRawTxTokenTransfer + 4 + 32 ];
            }

        }

    }

    function ecrecoverSigner(
        bytes32 _hashTx,
        bytes _rsvTx,
        uint offset
    ) internal pure returns (address ecrecoverAddress){

        bytes32 r;
        bytes32 s;
        bytes1 v;

        assembly {
            r := mload(add(_rsvTx,add(offset,0x20)))
            s := mload(add(_rsvTx,add(offset,0x40)))
            v := mload(add(_rsvTx,add(offset,0x60)))
        }

        ecrecoverAddress = ecrecover(
            _hashTx,
            uint8(v),
            r,
            s
        );
    }



    function decodeRawTxGetWithdrawalInfo(bytes memory _signedRawTxWithdrawal, uint8 _chainId) internal pure returns (address withdrawalSigner, uint256 withdrawalAmount) {

        bytes4 _selector;
        bytes memory _withdrawalData;
        RLPReader.RLPItem[] memory _signedRawTxWithdrawalRLPItem = _signedRawTxWithdrawal.toRlpItem().toList();

        _withdrawalData = _signedRawTxWithdrawalRLPItem[5].toBytes();

        assembly { _selector := mload(add(_withdrawalData,0x20))}

        withdrawalSigner = getSignerFromSignedRawTxRLPItemp(_signedRawTxWithdrawalRLPItem,_chainId);

        // 0x835fc6ca : bytes4(keccak256('withdrawal(uint256)'))
        if(_selector == 0x835fc6ca ) {

            assembly {
                withdrawalAmount := mload(add(_withdrawalData,add(4,0x20)))
            }

        }

    }



    function getSignerFromSignedRawTxRLPItemp(RLPReader.RLPItem[] memory _signedTxRLPItem, uint8 _chainId) internal pure returns (address ecrecoverAddress) {
        bytes memory _rawTx;
        bytes memory _rsvTx;

        (_rawTx, _rsvTx ) = explodeSignedRawTxRLPItem(_signedTxRLPItem, _chainId);
        return ecrecoverSigner(keccak256(_rawTx), _rsvTx,0);
    }

    function explodeSignedRawTxRLPItem(RLPReader.RLPItem[] memory _signedTxRLPItem, uint8 _chainId) internal pure returns (bytes memory _rawTx,bytes memory _rsvTx){

        bytes[] memory _signedTxRLPItemRaw = new bytes[](9);

        _signedTxRLPItemRaw[0] = RLPWriter.toRlp(_signedTxRLPItem[0].toBytes());
        _signedTxRLPItemRaw[1] = RLPWriter.toRlp(_signedTxRLPItem[1].toBytes());
        _signedTxRLPItemRaw[2] = RLPWriter.toRlp(_signedTxRLPItem[2].toBytes());
        _signedTxRLPItemRaw[3] = RLPWriter.toRlp(_signedTxRLPItem[3].toBytes());
        _signedTxRLPItemRaw[4] = RLPWriter.toRlp(_signedTxRLPItem[4].toBytes());
        _signedTxRLPItemRaw[5] = RLPWriter.toRlp(_signedTxRLPItem[5].toBytes());

        _signedTxRLPItemRaw[6] = RLPWriter.toRlp(_chainId);
        _signedTxRLPItemRaw[7] = RLPWriter.toRlp(0);
        _signedTxRLPItemRaw[8] = RLPWriter.toRlp(0);

        _rawTx = RLPWriter.toRlp(_signedTxRLPItemRaw);

        uint8 i;
        _rsvTx = new bytes(65);

        bytes32 tmp = bytes32(_signedTxRLPItem[7].toUint());
        for (i = 0; i < 32; i++) {
            _rsvTx[i] = tmp[i];
        }

        tmp = bytes32(_signedTxRLPItem[8].toUint());

        for (i = 0; i < 32; i++) {
            _rsvTx[i + 32] = tmp[i];
        }

        _rsvTx[64] = bytes1(_signedTxRLPItem[6].toUint() - uint(_chainId * 2) - 8);

    }

}
