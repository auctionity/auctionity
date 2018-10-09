pragma solidity ^0.4.24;

contract AuctionityRecorder {
    string public version = "recorder-v1";

    address public owner;
    address public oracle;

    address public auctionityAuctionFactoryAddress;

    mapping (bytes32 => uint8) public tokenHash;

    enum tokenHashState {
        UNKNOWN,
        PENDING,
        OK,
        USED
    }

    event LogRecorderTokenHashPending(bytes32 tokenHash, address auctionSeller, address tokenContractAddress, uint tokenId);
    event LogRecorderTokenHashOk(bytes32 tokenHash, address auctionSeller, address tokenContractAddress, uint tokenId);
    event LogRecorderTokenHashUsed(bytes32 tokenHash, address auctionSeller, address tokenContractAddress, uint tokenId);
    event LogRecorderTokenHashRefused(bytes32 tokenHash, address auctionSeller, address tokenContractAddress, uint tokenId);
    event LogError(string version, string error);

    constructor() public {
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

    modifier isAuctionFactory() {
        require(msg.sender == auctionityAuctionFactoryAddress, "Sender must be AuctionFactory");
        _;
    }

    function setOracle(address _oracle) public isOwner {
        oracle = _oracle;
    }

    function setAuctionityAuctionFactoryAddress(address _auctionityAuctionFactoryAddress) public isOwner {
        auctionityAuctionFactoryAddress = _auctionityAuctionFactoryAddress;
    }

    function getTokenHashState(bytes32 _tokenHash) public view returns(uint8) {
        return uint8(tokenHash[_tokenHash]);
    }

    function verify(
        bytes32 _tokenHash,
        address _auctionSeller,
        address _tokenContractAddress,
        uint _tokenId
    ) external isAuctionFactory returns(bool) {
        if(tokenHash[_tokenHash] == uint8(tokenHashState.UNKNOWN)) {
            tokenHash[_tokenHash] = uint8(tokenHashState.PENDING);
            emit LogRecorderTokenHashPending(_tokenHash, _auctionSeller, _tokenContractAddress, _tokenId);
            return true;
        }

        return tokenHash[_tokenHash] == uint8(tokenHashState.OK);
    }

    function stateIsOK(bytes32 _tokenHash) external isAuctionFactory view returns(bool) {
        return tokenHash[_tokenHash] == uint8(tokenHashState.OK);
    }

    function setTokenHashOk(
        bytes32 _tokenHash,
        address _auctionSeller,
        address _tokenContractAddress,
        uint _tokenId
    ) external isAuctionFactory returns(bool) {
        if (
            tokenHash[_tokenHash] == uint8(tokenHashState.UNKNOWN) ||
            tokenHash[_tokenHash] == uint8(tokenHashState.PENDING)
        ) {
            tokenHash[_tokenHash] = uint8(tokenHashState.OK);
            emit LogRecorderTokenHashOk(_tokenHash, _auctionSeller, _tokenContractAddress, _tokenId);

            return true;
        }

        return false;
    }

    function setTokenHashUsed(
        bytes32 _tokenHash,
        address _auctionSeller,
        address _tokenContractAddress,
        uint _tokenId
    ) external isAuctionFactory returns(bool) {
        if(tokenHash[_tokenHash] == uint8(tokenHashState.OK)) {
            tokenHash[_tokenHash] = uint8(tokenHashState.USED);
            emit LogRecorderTokenHashUsed(_tokenHash, _auctionSeller, _tokenContractAddress, _tokenId);

            return true;
        }

        return false;
    }

    function setTokenHashRefused(
        bytes32 _tokenHash,
        address _auctionSeller,
        address _tokenContractAddress,
        uint _tokenId
        ) external isAuctionFactory returns(bool) {

        if (
            tokenHash[_tokenHash] == uint8(tokenHashState.UNKNOWN) ||
            tokenHash[_tokenHash] == uint8(tokenHashState.PENDING)
        ) {
            tokenHash[_tokenHash] = uint8(tokenHashState.UNKNOWN);
            emit LogRecorderTokenHashRefused(_tokenHash, _auctionSeller, _tokenContractAddress, _tokenId);
            return true;
        }

        return false;
    }
}
