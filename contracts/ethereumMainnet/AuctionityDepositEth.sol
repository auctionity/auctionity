pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./AuctionityLibraryDecodeRawTx.sol";
import "./AuctionityLibraryDeposit.sol";

contract AuctionityDepositEth {
    using SafeMath for uint256;

    string public version = "deposit-eth-v1";

    address public owner;
    address public oracle;
    uint8 public ethereumChainId;
    uint8 public auctionityChainId;
    bool public migrationLock;
    bool public maintenanceLock;

    mapping (address => uint256) public depotEth;  // Depot for users (concatenate struct into uint256)

    bytes32[] public withdrawalVoucherList;                     // List of withdrawal voucher
    mapping (bytes32 => bool) public withdrawalVoucherSubmitted; // is withdrawal voucher is already submitted

    bytes32[] public auctionEndVoucherList;                     // List of auction end voucher
    mapping (bytes32 => bool) public auctionEndVoucherSubmitted; // is auction end voucher is already submitted

    struct InfoFromCreateAuction {
        bytes32 tokenHash;
        address tokenContractAddress;
        address auctionSeller;
        uint8 rewardPercent;
        uint256 tokenId;
    }

    struct InfoFromBidding {
        address auctionContractAddress;
        address signer;
        uint256 amount;
    }

    // events
    event LogDeposed(address user, uint256 amount);
    event LogWithdrawalVoucherSubmitted(address user, uint256 amount, bytes32 withdrawalVoucherHash);

    event LogAuctionEndVoucherSubmitted(
        bytes32 tokenHash,
        address tokenContractAddress,
        uint256 tokenId,
        address indexed seller,
        address indexed winner,
        uint256 amount,
        bytes32 auctionEndVoucherHash
    );
    event LogSentEthToWinner(address auction, address user, uint256 amount);
    event LogSentEthToAuctioneer(address auction, address user, uint256 amount);
    event LogSentDepotEth(address user, uint256 amount);
    event LogSentRewardsDepotEth(address[] user, uint256[] amount);

    event LogError(string version,string error);
    event LogErrorWithData(string version, string error, bytes32[] data);


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

    modifier migrationLockable() {
        require(!migrationLock || msg.sender == owner, "MIGRATION_LOCKED");
        _;
    }

    function setMigrationLock(bool _lock) public isOwner {
        migrationLock = _lock;
    }

    modifier maintenanceLockable() {
        require(!maintenanceLock || msg.sender == owner, "MAINTENANCE_LOCKED");
        _;
    } 

    function setMaintenanceLock(bool _lock) public isOwner {
        maintenanceLock = _lock;
    }

    // add depot from user
    function addDepotEth(address _user, uint256 _amount) private returns (bool) {
        depotEth[_user] = depotEth[_user].add(_amount);
        return true;
    }

    // sub depot from user
    function subDepotEth(address _user, uint256 _amount) private returns (bool) {
        if(depotEth[_user] < _amount){
            return false;
        }

        depotEth[_user] = depotEth[_user].sub(_amount);
        return true;
    }

    // get amount of user's deposit
    function getDepotEth(address _user) public view returns(uint256 _amount) {
        return depotEth[_user];
    }

    // fallback payable function , with revert if is deactivated
    function() public payable {
        return depositEth();
    }

    // payable deposit eth
    function depositEth() public payable migrationLockable maintenanceLockable {
        bytes32[] memory _errorData;
        uint256 _amount = uint256(msg.value);
        require(_amount > 0, "Amount must be greater than 0");

        if(!addDepotEth(msg.sender, _amount)) {
            _errorData = new bytes32[](1);
            _errorData[0] = bytes32(_amount);
            emit LogErrorWithData(version, "DEPOSED_ADD_DATA_FAILED", _errorData);
            return;
        }

        emit LogDeposed(msg.sender, _amount);
    }

    /**
     * withdraw
     * @dev Param
     *      bytes32 r ECDSA signature
     *      bytes32 s ECDSA signature
     *      uint8 v ECDSA signature
     *      address user
     *      uint256 amount
     *      bytes32 key : anti replay
     * @dev Log
     *      LogWithdrawalVoucherSubmitted : successful
     */
    function withdrawalVoucher(
        bytes memory _data,
        bytes memory _signedRawTxWithdrawal
    ) public maintenanceLockable {
        bytes32 _withdrawalVoucherHash = keccak256(_signedRawTxWithdrawal);

        // if withdrawal voucher is already submitted
        if(withdrawalVoucherSubmitted[_withdrawalVoucherHash] == true) {
            emit LogError(version, "WITHDRAWAL_VOUCHER_ALREADY_SUBMITED");
            return;
        }

        address _withdrawalSigner;
        uint _withdrawalAmount;

        (_withdrawalSigner, _withdrawalAmount) = AuctionityLibraryDecodeRawTx.decodeRawTxGetWithdrawalInfo(_signedRawTxWithdrawal, auctionityChainId);
        
        if(_withdrawalAmount == uint256(0)) {
            emit LogError(version,'WITHDRAWAL_VOUCHER_AMOUNT_INVALID');
            return;
        }

        if(_withdrawalSigner == address(0)) {
            emit LogError(version,'WITHDRAWAL_VOUCHER_SIGNER_INVALID');
            return;
        }

        // if depot is smaller than amount
        if(depotEth[_withdrawalSigner] < _withdrawalAmount) {
            emit LogError(version,'WITHDRAWAL_VOUCHER_DEPOT_AMOUNT_TOO_LOW');
            return;
        }

        if(!withdrawalVoucherOracleSignatureVerification(_data, _withdrawalSigner, _withdrawalAmount, _withdrawalVoucherHash)) {
            emit LogError(version,'WITHDRAWAL_VOUCHER_ORACLE_INVALID_SIGNATURE');
            return;
        }

        // send amount
        if(!_withdrawalSigner.send(_withdrawalAmount)) {
            emit LogError(version, "WITHDRAWAL_VOUCHER_ETH_TRANSFER_FAILED");
            return;
        }

        subDepotEth(_withdrawalSigner,_withdrawalAmount);

        withdrawalVoucherList.push(_withdrawalVoucherHash);
        withdrawalVoucherSubmitted[_withdrawalVoucherHash] = true;

        emit LogWithdrawalVoucherSubmitted(_withdrawalSigner,_withdrawalAmount, _withdrawalVoucherHash);
    }

    function withdrawalVoucherOracleSignatureVerification(
        bytes memory _data,
        address _withdrawalSigner,
        uint256 _withdrawalAmount,
        bytes32 _withdrawalVoucherHash
    ) internal view returns (bool)
    {

        // if oracle is the signer of this auction end voucher
        return oracle == AuctionityLibraryDecodeRawTx.ecrecoverSigner(
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(
                        abi.encodePacked(
                            address(this),
                            _withdrawalSigner,
                            _withdrawalAmount,
                            _withdrawalVoucherHash
                        )
                    )
                )
            ),
            _data,
            0
        );
    }

    /**
     * auctionEndVoucher
     * @dev Param
     *      bytes _data is a  concatenate of :
     *            bytes64 biddingHashProof
     *            bytes130 rsv ECDSA signature of oracle validation AEV
     *            bytes transfer token
     *      bytes _signedRawTxCreateAuction raw transaction with rsv of bidding transaction on auction smart contract
     *      bytes _signedRawTxBidding raw transaction with rsv of bidding transaction on auction smart contract
     *      bytes _send list of sending eth
     * @dev Log
     *      LogAuctionEndVoucherSubmitted : successful
     */

    function auctionEndVoucher(
        bytes memory _data,
        bytes memory _signedRawTxCreateAuction,
        bytes memory _signedRawTxBidding,
        bytes memory _send
    ) public maintenanceLockable {
        bytes32 _auctionEndVoucherHash = keccak256(_signedRawTxCreateAuction);
        // if auction end voucher is already submitted
        if(auctionEndVoucherSubmitted[_auctionEndVoucherHash] == true) {
            emit LogError(version, "AUCTION_END_VOUCHER_ALREADY_SUBMITED");
            return;
        }

        InfoFromCreateAuction memory _infoFromCreateAuction = getInfoFromCreateAuction(_signedRawTxCreateAuction);

        address _auctionContractAddress;
        address _winnerSigner;
        uint256 _winnerAmount;

        InfoFromBidding memory _infoFromBidding;

        if(_signedRawTxBidding.length > 1) {
            _infoFromBidding = getInfoFromBidding(_signedRawTxBidding, _infoFromCreateAuction.tokenHash);

            if(!verifyWinnerDepot(_infoFromBidding)) {
                return;
            }
        }

        if(!auctionEndVoucherOracleSignatureVerification(
            _data,
            keccak256(_send),
            _infoFromCreateAuction,
            _infoFromBidding
        )) {
            emit LogError(version, "AUCTION_END_VOUCHER_ORACLE_INVALID_SIGNATURE");
            return;
        }

        if(!AuctionityLibraryDeposit.sendTransfer(_infoFromCreateAuction.tokenContractAddress, _data, 97)){
            if(_data[97] > 0x01) {// if more than 1 transfer function to call
                revert("More than one transfer function to call");
            } else {
                emit LogError(version, "AUCTION_END_VOUCHER_TRANSFER_FAILED");
                return;
            }
        }

        if(_signedRawTxBidding.length > 1) {
            if(!sendExchange(_send, _infoFromCreateAuction, _infoFromBidding)) {
                return;
            }
        }


        auctionEndVoucherList.push(_auctionEndVoucherHash);
        auctionEndVoucherSubmitted[_auctionEndVoucherHash] = true;
        emit LogAuctionEndVoucherSubmitted(
            _infoFromCreateAuction.tokenHash,
            _infoFromCreateAuction.tokenContractAddress,
            _infoFromCreateAuction.tokenId,
            _infoFromCreateAuction.auctionSeller,
            _infoFromBidding.signer,
            _infoFromBidding.amount,
            _auctionEndVoucherHash
        );
    }

    function getInfoFromCreateAuction(bytes _signedRawTxCreateAuction) internal view returns
        (InfoFromCreateAuction memory _infoFromCreateAuction)
    {
        (
            _infoFromCreateAuction.tokenHash,
            ,
            _infoFromCreateAuction.auctionSeller,
            _infoFromCreateAuction.tokenContractAddress,
            _infoFromCreateAuction.tokenId,
            _infoFromCreateAuction.rewardPercent
        ) = AuctionityLibraryDecodeRawTx.decodeRawTxGetCreateAuctionInfo(_signedRawTxCreateAuction,auctionityChainId);
    }

    function getInfoFromBidding(bytes _signedRawTxBidding, bytes32 _hashSignedRawTxTokenTransfer) internal returns (InfoFromBidding memory _infoFromBidding) {
        bytes32 _hashRawTxTokenTransferFromBid;

        (
            _hashRawTxTokenTransferFromBid,
            _infoFromBidding.auctionContractAddress,
            _infoFromBidding.amount,
            _infoFromBidding.signer
        ) = AuctionityLibraryDecodeRawTx.decodeRawTxGetBiddingInfo(_signedRawTxBidding,auctionityChainId);

        if(_hashRawTxTokenTransferFromBid != _hashSignedRawTxTokenTransfer) {
            emit LogError(version, "AUCTION_END_VOUCHER_hashRawTxTokenTransfer_INVALID");
            return;
        }

        if(_infoFromBidding.amount == uint256(0)){
            emit LogError(version, "AUCTION_END_VOUCHER_BIDDING_AMOUNT_INVALID");
            return;
        }

    }    

    function verifyWinnerDepot(InfoFromBidding memory _infoFromBidding) internal returns(bool) {
        // if depot is smaller than amount
        if(depotEth[_infoFromBidding.signer] < _infoFromBidding.amount) {
            emit LogError(version, "AUCTION_END_VOUCHER_DEPOT_AMOUNT_TOO_LOW");
            return false;
        }

        return true;
    }

    function sendExchange(
        bytes memory _send,
        InfoFromCreateAuction memory _infoFromCreateAuction,
        InfoFromBidding memory _infoFromBidding
    ) internal returns(bool) {
        if(!subDepotEth(_infoFromBidding.signer, _infoFromBidding.amount)){
            emit LogError(version, "AUCTION_END_VOUCHER_DEPOT_AMOUNT_TOO_LOW");
            return false;
        }

        uint offset;
        address _sendAddress;
        uint256 _sendAmount;
        bytes12 _sendAmountGwei;
        uint256 _sentAmount;

        assembly {
            _sendAddress := mload(add(_send,add(offset,0x14)))
            _sendAmount := mload(add(_send,add(add(offset,20),0x20)))
        }

        if(_sendAddress != _infoFromCreateAuction.auctionSeller){
            emit LogError(version, "AUCTION_END_VOUCHER_SEND_TO_SELLER_INVALID");
            return false;
        }

        _sentAmount += _sendAmount;
        offset += 52;

        if(!_sendAddress.send(_sendAmount)) {
            revert("Failed to send funds");
        }

        emit LogSentEthToWinner(_infoFromBidding.auctionContractAddress, _sendAddress, _sendAmount);

        if(_infoFromCreateAuction.rewardPercent > 0) {
            assembly {
                _sendAddress := mload(add(_send,add(offset,0x14)))
                _sendAmount := mload(add(_send,add(add(offset,20),0x20)))
            }

            _sentAmount += _sendAmount;
            offset += 52;

            if(!_sendAddress.send(_sendAmount)) {
                revert("Failed to send funds");
            }

            emit LogSentEthToAuctioneer(_infoFromBidding.auctionContractAddress, _sendAddress, _sendAmount);

            bytes2 _numberOfSendDepositBytes2;
            assembly {
                _numberOfSendDepositBytes2 := mload(add(_send,add(offset,0x20)))
            }

            offset += 2;

            address[] memory _rewardsAddress = new address[](uint16(_numberOfSendDepositBytes2));
            uint256[] memory _rewardsAmount = new uint256[](uint16(_numberOfSendDepositBytes2));

            for (uint16 i = 0; i < uint16(_numberOfSendDepositBytes2); i++){

                assembly {
                    _sendAddress := mload(add(_send,add(offset,0x14)))
                    _sendAmountGwei := mload(add(_send,add(add(offset,20),0x20)))
                }

                _sendAmount = uint96(_sendAmountGwei) * 1000000000;
                _sentAmount += _sendAmount;
                offset += 32;

                if(!addDepotEth(_sendAddress, _sendAmount)) {
                    revert("Can't add deposit");
                }

                _rewardsAddress[i] = _sendAddress;
                _rewardsAmount[i] = uint256(_sendAmount);
            }

            emit LogSentRewardsDepotEth(_rewardsAddress, _rewardsAmount);
        }

        if(uint256(_infoFromBidding.amount) != _sentAmount) {
            revert("Bidding amount is not equal to sent amount");
        }

        return true;
    }

    function getTransferDataHash(bytes memory _data) internal returns (bytes32 _transferDataHash){
        bytes memory _transferData = new bytes(_data.length - 97);

        for (uint i = 0; i < (_data.length - 97); i++) {
            _transferData[i] = _data[i + 97];
        }
        return keccak256(_transferData);

    }

    function auctionEndVoucherOracleSignatureVerification(
        bytes memory _data,
        bytes32 _sendDataHash,
        InfoFromCreateAuction memory _infoFromCreateAuction,
        InfoFromBidding memory _infoFromBidding
    ) internal returns (bool) {
        bytes32 _biddingHashProof;
        assembly { _biddingHashProof := mload(add(_data,add(0,0x20))) }

        bytes32 _transferDataHash = getTransferDataHash(_data);

        // if oracle is the signer of this auction end voucher
        return oracle == AuctionityLibraryDecodeRawTx.ecrecoverSigner(
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(
                        abi.encodePacked(
                            address(this),
                            _infoFromCreateAuction.tokenContractAddress,
                            _infoFromCreateAuction.tokenId,
                            _infoFromCreateAuction.auctionSeller,
                            _infoFromBidding.signer,
                            _infoFromBidding.amount,
                            _biddingHashProof,
                            _infoFromCreateAuction.rewardPercent,
                            _transferDataHash,
                            _sendDataHash
                        )
                    )
                )
            ),
            _data,
            32
        );

    }
}