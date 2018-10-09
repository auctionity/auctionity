pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./SafeMath96.sol";
import "./SafeMath32.sol";
import "./AuctionityLibraryDecodeRawTx.sol";

contract AuctionityDebug {
    using SafeMath for uint256;
    using SafeMath96 for uint96;
    using SafeMath32 for uint32;

    string public version = "debug-v1";

    uint8 public ethereumChainId = 1;
    uint8 public auctionityChainId = 4;

    // todo For Debug Only
    event LogBytes(bytes value);
    event LogBytes1(bytes1 value);
    event LogBytes32(bytes32 value);
    event LogAddress(address value);
    event LogUint(uint value);
    event LogBool(bool value);
    event LogString(string value);
    event LogBidSponsor(address bidder, address sponsor, uint32 bidTimestamp);
    event LogRewards(address sponsor, uint32 timeLeading, uint amount);
    event LogDebug1(address address1, uint32 timeLeading1, address address2, uint32 timeLeading2);
    event LogDebug2(address address1, uint32 timeLeading1, address address2, uint32 timeLeading2);

    constructor() public {

    }

    function debugTransferVerification(bytes memory _signedRawTxTokenTransfer) public {
        address _tokenContractAddress;
        address _auctionSeller;
        uint _tokenId;

        emit LogBytes(_signedRawTxTokenTransfer);
/* AuctionityLibraryDecodeRawTx.decodeRawTxGetErc721Info does'nt exist

        (_tokenContractAddress, _auctionSeller, _tokenId) = AuctionityLibraryDecodeRawTx.decodeRawTxGetErc721Info(
            _signedRawTxTokenTransfer,
            ethereumChainId
        );
*/
        emit LogAddress(_tokenContractAddress);
        emit LogAddress(_auctionSeller);
        emit LogUint(_tokenId);
    }

    function debugAuctionEndVoucherCreateVerification(bytes memory _signedRawTxCreateAuction) public {
        bytes32 _hashRawTxTokenTransferFromCreate;
        address _auctionFactoryContractAddress;
        address _auctionCreator;
        address _tokenContractAddress;
        uint256 _tokenId;
        uint8 _rewardPercent;

        emit LogBytes(_signedRawTxCreateAuction);

        (
            _hashRawTxTokenTransferFromCreate,
            _auctionFactoryContractAddress, 
            _auctionCreator, 
            _tokenContractAddress, 
            _tokenId, 
            _rewardPercent
        ) = AuctionityLibraryDecodeRawTx.decodeRawTxGetCreateAuctionInfo(_signedRawTxCreateAuction, auctionityChainId);

        emit LogBytes32(_hashRawTxTokenTransferFromCreate);
        emit LogAddress(_auctionFactoryContractAddress);
        emit LogAddress(_auctionCreator);
        emit LogAddress(_tokenContractAddress);
        emit LogUint(_tokenId);
        emit LogUint(_rewardPercent);
    }

    function debugAuctionEndVoucherBidVerification(bytes memory _signedRawTxBid) public {
        bytes32 _hashRawTxTokenTransferFromBid;
        address _auctionContractAddress;
        address _signerBid;
        uint256 _bidAmount;

        emit LogBytes(_signedRawTxBid);

        (
            _hashRawTxTokenTransferFromBid,
            _auctionContractAddress,
            _bidAmount,
            _signerBid
        ) = AuctionityLibraryDecodeRawTx.decodeRawTxGetBiddingInfo(_signedRawTxBid, auctionityChainId);

        emit LogBytes32(_hashRawTxTokenTransferFromBid);
        emit LogAddress(_auctionContractAddress);
        emit LogUint(_bidAmount);
        emit LogAddress(_signerBid);
    }

    function debugDecodeRawTxGetWithdrawalInfo(bytes _signedRawTxWithdrawal) public returns (address _withdrawalSigner, uint256 _withdrawalAmount) {
        emit LogBytes(_signedRawTxWithdrawal);

        ( _withdrawalSigner, _withdrawalAmount) = AuctionityLibraryDecodeRawTx.decodeRawTxGetWithdrawalInfo(_signedRawTxWithdrawal,auctionityChainId);
        emit LogAddress(_withdrawalSigner);
        emit LogUint(_withdrawalAmount);
    }
}
