pragma solidity 0.4.23;

import "./AuctionitySafeMath.sol";

contract AuctionityDepositEth {
    using AuctionitySafeMath for uint248;

    string public version = 'deposit-eth-v0';

    address public owner;
    address public oracle;

    // Amount of deposit
    struct DepotData {
        uint248 amount; // amount of depot
        uint8 isSet;    // is value amount is already set (if not set, push into depotEthList)
    }

    address[] public depotEthList;                 // List of deposit users
    mapping (address => uint256) public depotEth;  // DepotData for users (concatenate struct into uint256)

    bytes32[] public withdrawalVoucherList;                     // List of withdrawal voucher
    mapping (bytes32 => bool) public withdrawalVoucherSubmited; // is withdrawal voucher is already submited

    bytes32[] public auctionEndVoucherList;                     // List of auction end voucher
    mapping (bytes32 => bool) public auctionEndVoucherSubmited; // is auction end voucher is already submited


    // Error Codes
    enum Errors {
        DEPOSED_ADD_DATA_FAILED,
        WITHDRAWAL_VOUCHER_DEPOT_NOT_FOUND,
        WITHDRAWAL_VOUCHER_DEPOT_AMOUNT_TOO_LOW,
        WITHDRAWAL_VOUCHER_ALREADY_SUBMITED,
        WITHDRAWAL_VOUCHER_INVALID_SIGNATURE,
        WITHDRAWAL_VOUCHER_ETH_TRANSFERT_FAILED,
        AUCTION_END_VOUCHER_DEPOT_NOT_FOUND,
        AUCTION_END_VOUCHER_DEPOT_AMOUNT_TOO_LOW,
        AUCTION_END_VOUCHER_ALREADY_SUBMITED,
        AUCTION_END_VOUCHER_INVALID_SIGNATURE,
        AUCTION_END_VOUCHER_ETH_TRANSFERT_FAILED
    }

    // events
    event LogDeposed(address user, uint248 amount);
    event LogWithdrawalVoucherSubmited(address user, uint248 amount, bytes32 key);
    event LogAuctionEndVoucherSubmited(address indexed seller, address indexed winner, uint248 amount, bytes32 biddingHashProof, address indexed auctionSC);
    event LogSetDeposed(string raison, address user, uint248 amount, uint248 oldAmount);
    event LogReceiveMigrateDataAddDepotFailed(address user, uint248 amount);
    event LogReceiveMigrationDepotEthDataCompleted(uint256 receiveCount,uint256 depotEthListCount);
    event LogReceiveMigrationDataWithdrawalVoucherCompleted(uint256 withdrawalVoucherCount);
    event LogReceiveMigrationDataAuctionEndVoucherCompleted(uint256 auctionEndVoucherCount);
    event LogMigrationAmountCompleted(address migrateTo, uint256 totalAmount);
    event LogMigrationDepotEthAmountTooLow(address migrateTo, uint256 totalAmount);
    event LogError(uint8 indexed errorId);
    event LogErrorWithData(uint8 indexed errorId,bytes32[] data);

    constructor() public {
        owner = msg.sender;
    }

    // Modifier
    modifier isOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier isOracle() {
        require(msg.sender == oracle);
        _;
    }

    function setOracle(address _oracle)
    isOwner
    public {
        oracle = _oracle;
    }

    // add depot from user
    function addDepotEth(address user,uint248 amount) private returns (bool){
        DepotData memory depotData = getDepotEthStruct(user);

        uint248 depotUserAmount = amount;

        if(depotData.amount > 0){
            depotUserAmount = depotData.amount.safeAdd248(amount);
        }

        setDepotEth(user, depotUserAmount);
        return true;
    }

    // set depot into DepotData concat
    function setDepotEth(address user,uint248 amount) private returns (bool){
        DepotData memory depotData = getDepotEthStruct(user);

        if(depotData.isSet == 0){
            depotEthList.push(user);
        }
        uint256 depotUser = uint8(1);
        depotUser |= uint248(amount)<<8;
        depotEth[user] = depotUser;


        return true;
    }

    // get amount of user's deposit
    function getDepotEth(address user)
    public view
    returns(uint248 amount) {
        return uint248(depotEth[user]>>8);
    }

    // get DepotData of user's deposit
    function getDepotEthStruct(address user)
    private view
    returns(DepotData memory _depotData) {
        _depotData.isSet = uint8(depotEth[user]);
        _depotData.amount = uint248(depotEth[user]>>8);

    }

    // fallback payable function , with revert if is deactivated
    function() public payable{
        return depositEth();
    }

    // payable deposit eth
    function depositEth() public payable
    {
        bytes32[] memory ErrorData;
        uint248 amount = uint248(msg.value);
        require(amount > 0);

        if(!addDepotEth(msg.sender, amount)) {
            ErrorData = new bytes32[](1);
            ErrorData[0] = bytes32(amount);
            emit LogErrorWithData(uint8(Errors.DEPOSED_ADD_DATA_FAILED), ErrorData);
            return;
        }

        emit LogDeposed(msg.sender, amount);
    }

    /**
     * withdraw
     * @dev Param
     *      bytes32 r ECDSA signature
     *      bytes32 s ECDSA signature
     *      uint8 v ECDSA signature
     *      address user
     *      uint248 amount
     *      bytes32 key : anti replay
     * @dev Log
     *      LogWithdrawalVoucherSubmited : successful
     */

    function withdrawalVoucher(
        bytes32 r,
        bytes32 s,
        uint8 v,
        address user,
        uint248 amount,
        bytes32 key
    )
    public
    {
        require(
            user != address(0)
            && amount != 0
            && key != bytes32(0)
        );
        bytes32[] memory ErrorData;

        DepotData memory depotData = getDepotEthStruct(user);

        // if no depot for user
        if(depotData.isSet == 0){
            emit LogError(uint8(Errors.WITHDRAWAL_VOUCHER_DEPOT_NOT_FOUND));
            return;
        }
        // if depot is smaller than amount
        if(depotData.amount < amount)
        {
            emit LogError(uint8(Errors.WITHDRAWAL_VOUCHER_DEPOT_AMOUNT_TOO_LOW));
            return;
        }
        bytes32 hash = keccak256(abi.encodePacked(user, amount, key));

        // if withdrawal voucher is already submited
        if(withdrawalVoucherSubmited[hash] == true)
        {
            ErrorData = new bytes32[](1);
            ErrorData[0] = bytes32(hash);
            emit LogErrorWithData(uint8(Errors.WITHDRAWAL_VOUCHER_ALREADY_SUBMITED),ErrorData);
            return;
        }

        // if oracle is the signer of this withdrawal voucher
        if(!isValidSignature(oracle,hash, r, s, v))
        {
            emit LogError(uint8(Errors.WITHDRAWAL_VOUCHER_INVALID_SIGNATURE));
            return;
        }

        uint248 depotUserAmount = depotData.amount.safeSub248(amount);

        // send amount
        if(!user.send(uint256(amount)))
        {
            emit LogError(uint8(Errors.WITHDRAWAL_VOUCHER_ETH_TRANSFERT_FAILED));
            return;
        }
        setDepotEth(user,depotUserAmount);

        withdrawalVoucherList.push(hash);
        withdrawalVoucherSubmited[hash] = true;
        emit LogWithdrawalVoucherSubmited(user,amount,key);
    }

    /**
     * auctionEndVoucher
     * @dev Param
     *      bytes32 r ECDSA signature
     *      bytes32 s ECDSA signature
     *      uint8 v ECDSA signature
     *      address user
     *      uint248 amount
     *      bytes32 biddingHashProof
     *      address auctionSC
     * @dev Log
     *      LogWithdrawalVoucherSubmited : successful
     */

    function auctionEndVoucher(
        bytes32 r,
        bytes32 s,
        uint8 v,
        address winner,
        uint248 amount,
        bytes32 biddingHashProof,
        address auctionSC
    ) public
    {
        require(
            winner != address(0)
            && amount != 0
            && auctionSC != address(0)
        );

        bytes32[] memory ErrorData;

        address seller = msg.sender;

        DepotData memory depotData = getDepotEthStruct(winner);

        // if no depot for winner
        if(depotData.isSet == 0){
            emit LogError(uint8(Errors.AUCTION_END_VOUCHER_DEPOT_NOT_FOUND));
            return;
        }
        // if depot is smaller than amount
        if(depotData.amount < amount)
        {
            emit LogError(uint8(Errors.AUCTION_END_VOUCHER_DEPOT_AMOUNT_TOO_LOW));
            return;
        }

        bytes32 hash = keccak256(abi.encodePacked(seller, winner, amount, biddingHashProof, auctionSC));

        // if auction end voucher is already submited
        if(auctionEndVoucherSubmited[hash] == true)
        {
            ErrorData = new bytes32[](1);
            ErrorData[0] = bytes32(hash);
            emit LogErrorWithData(uint8(Errors.AUCTION_END_VOUCHER_ALREADY_SUBMITED),ErrorData);
            return;
        }

        // if oracle is the signer of this auction end voucher
        if(!isValidSignature(oracle,hash, r, s, v))
        {
            emit LogError(uint8(Errors.AUCTION_END_VOUCHER_INVALID_SIGNATURE));
            return;
        }

        uint248 depotUserAmount = depotData.amount.safeSub248(amount);

        // send amount
        if(!seller.send(uint256(amount)))
        {
            emit LogError(uint8(Errors.AUCTION_END_VOUCHER_ETH_TRANSFERT_FAILED));
            return;
        }

        setDepotEth(winner,depotUserAmount);

        auctionEndVoucherList.push(hash);
        auctionEndVoucherSubmited[hash] = true;
        emit LogAuctionEndVoucherSubmited(seller, winner, amount, biddingHashProof, auctionSC);
    }

    /**
     * isValidSignature
     * @dev Verifies that an hash signature is valid
     *      signer address of signer
     *      hash Signed Keccak-256 hash
     *      bytes32 r ECDSA signature
     *      bytes32 s ECDSA signature
     *      uint8 v ECDSA signature
     * @return Validity of order signature
     */
    function isValidSignature(
        address signer,
        bytes32 hash,
        bytes32 r,
        bytes32 s,
        uint8 v)
    private
    pure
    returns (bool)
    {
        return signer == ecrecover(
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)),
            v,
            r,
            s
        );
    }
}