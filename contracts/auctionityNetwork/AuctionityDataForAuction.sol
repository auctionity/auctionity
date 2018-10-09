pragma solidity ^0.4.24;

contract AuctionityDecodeRawTxTransferNft {
    function decodeRawTxGetTransferInfo(
        bytes memory _signedRawTxTokenTransfer,
        uint8 _chainId,
        bytes32 _tokenContractAddressLink
    ) public returns (address _tokenContractAddress, address _addressOriginalOwnerOfErc721, address _addressDeposit, uint _tokenId);
}

contract AuctionityDataForAuction {
    string public version = "data4auction-v1";

    address public owner;
    address public oracle;
    address public auctionityAuctionFactoryAddress;
    address public auctionityTreasurerAddress;
    address public auctionityDecodeRawTxTransferNftAddress;
    AuctionityDecodeRawTxTransferNft auctionityDecodeRawTxTransferNft;

    uint8 public ethereumChainId;
    uint8 public auctionityChainId;

    address public clubSponsor;

    mapping (address => bytes32) public tokenContractAddressLink;

    // events
    event LogError(string version, string error);

    constructor(uint8 _ethereumChainId, uint8 _auctionityChainId) public {
        ethereumChainId = _ethereumChainId;
        auctionityChainId = _auctionityChainId;
        owner = msg.sender;
    }

    // Modifier
    modifier isOwner() {
        require(msg.sender == owner, "Sender must be owner");
        _;
    }

    modifier isOracle() {
        require(msg.sender == oracle, "Sender must be oracle");
        _;
    }

    function setOracle(address _oracle) public isOwner {
        oracle = _oracle;
    }

    function setAuctionityAuctionFactoryAddress(address _auctionityAuctionFactoryAddress) public isOwner {
        auctionityAuctionFactoryAddress = _auctionityAuctionFactoryAddress;
    }

    function setAuctionityTreasurerAddress(address _auctionityTreasurerAddress) public isOwner {
        auctionityTreasurerAddress = _auctionityTreasurerAddress;
    }

    function setAuctionityDecodeRawTxTransferNftAddress(address _auctionityDecodeRawTxTransferNftAddress) public isOwner{
        auctionityDecodeRawTxTransferNftAddress = _auctionityDecodeRawTxTransferNftAddress;
        auctionityDecodeRawTxTransferNft = AuctionityDecodeRawTxTransferNft(auctionityDecodeRawTxTransferNftAddress);
    }

    function setClubSponsorAddress(address _clubSponsor) public isOracle {
        clubSponsor = _clubSponsor;
    }

    function setTokenContractAddressLink(address _from, bytes32 _link) public isOwner {
        tokenContractAddressLink[_from] = _link;
    }

    function getTokenContractAddressLink(address _from) public view returns (bytes32 _link) {
        return tokenContractAddressLink[_from];
    }

    function decodeRawTxGetTransferInfo(
        bytes memory _signedRawTxTokenTransfer,
        uint8 _chainId,
        address _tokenContractAddress
    ) public view returns (address _tokenContractAddress2, address _addressOriginalOwnerOfErc721, address _addressDeposit, uint _tokenId){
        bytes32 _tokenContractAddressLink = getTokenContractAddressLink(_tokenContractAddress);
        // by default try with ERC721 decoding
        if(_tokenContractAddressLink == bytes32(0)){
            return auctionityDecodeRawTxTransferNft.decodeRawTxGetTransferInfo(_signedRawTxTokenTransfer, _chainId, 0x73ad2146b3d3a286642c794379d750360a2d53a3459a11b3e5d6cc900f55f44a);
        }
        return auctionityDecodeRawTxTransferNft.decodeRawTxGetTransferInfo(_signedRawTxTokenTransfer, _chainId, _tokenContractAddressLink);
    }
}
