pragma solidity 0.4.23;

import "./AuctionitySafeMath.sol";

contract AuctionityTreasurerEth {
    using AuctionitySafeMath for uint248;

    string public version = 'treasurer-eth-v0';

    address public owner;
    address public oracle;

    // Amount of locked deposit of auction
    struct DepotLockedData {
        uint248 amount;
        bool isValue;
    }

    struct DepotData {
        uint248 amount;                              // amount of deposit available
        mapping (address => DepotLockedData) locked; // Locked amount of a bid on auction smart contract
        address[] lockedList;                        // List of auction smart contract with a locked amount
        mapping (bytes => uint16) withdrawalVoucher; // Mapping of withdrawalVoucher => position into withdrawalVoucherList
        bytes[] withdrawalVoucherList;               // List of withdrawalVoucher
        bool isValue;                                // is value amount is already set (if not set, push into depotEthList)
    }
    
    address[] public depotEthList;                   // List of deposit users
    mapping (address => DepotData) public depotEth;  // DepotData for users

    // Error Codes
    enum Errors {
        LOCK_DEPOSIT_OVERFLOW,
        WITHDRAWAL_ZERO_AMOUNT,
        WITHDRAWAL_DEPOT_NOT_FOUND,
        WITHDRAWAL_DEPOT_AMOUNT_TOO_LOW,
        WITHDRAWAL_VOUCHER_ALREADY_ADDED
    }

    // Events
    event LogAddDepotEth(address user, uint248 amount, uint248 totalAmount);
    event LogWithdrawal(address user, uint248 amount);
    event LogAddWithdrawalVoucher(address user, bytes h);
    event LogWithdrawalVoucherHaveBeenRemoved(address user, bytes h);
    event LogNewDepotLock(address user, uint248 amount);
    event LogLockDepositRefund(address user, uint248 amount);
    event LogEndorse(address user, uint248 amount);
    event LogError(uint8 indexed errorId);


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
        public
    {
            oracle = _oracle;
    }
    
    /**
     * receiveDepotEth
     * @dev : Receive deposit of eth from livenet through oracle
     */
    function receiveDepotEth(address user, uint248 amount)
        public
        isOracle
        returns (bool)
    {

        if (depotEth[user].isValue == false) {
            depotEth[user].amount = amount;
            depotEth[user].isValue = true;
            depotEthList.push(user);
        } else {
            depotEth[user].amount = depotEth[user].amount.safeAdd248(amount);
        }
        emit LogAddDepotEth(user, amount, depotEth[user].amount);

        return true;
    }

    /**
     * lockDeposit
     * @dev Lock un part of deposit to a called smart contract
     *
     * tx.origin : origin user call parent smart contract
     * msg.sender : smart contract of parent smart contract
     */

    function lockDeposit(uint248 amount, address refundUser)
        external
        returns (bool) {

        if(!depotEth[tx.origin].isValue)
        {
            return false;
        }

        uint248 amountToLock = amount;

        // get amount to refund for previews bidder, 0 if doesn't exist
        uint248 refundAmount = depotEth[refundUser].locked[msg.sender].amount;

        // if refundUser is equal of currentUser , get difference between old and new amount
        if(refundUser == tx.origin)
        {
            amountToLock = amount.safeSub248(depotEth[tx.origin].locked[msg.sender].amount);
            refundAmount = 0;
        }

        // if deposit amount is smaller than amount to lock
        if (depotEth[tx.origin].amount < amountToLock) {
            return false;
        }

        // if is the first lock , push into list
        if(!depotEth[tx.origin].locked[msg.sender].isValue)
        {
            depotEth[tx.origin].lockedList.push(msg.sender);
        }

        depotEth[tx.origin].locked[msg.sender].amount = amount;
        depotEth[tx.origin].locked[msg.sender].isValue = true;
        depotEth[tx.origin].amount = depotEth[tx.origin].amount.safeSub248(amountToLock);

        emit LogNewDepotLock(tx.origin, amount);

        if (refundAmount > 0) {

            // expected overflow of depotEth
            uint248 newUserDepotAmount = depotEth[refundUser].amount + refundAmount;
            if(newUserDepotAmount < refundAmount) {
                emit LogError(uint8(Errors.LOCK_DEPOSIT_OVERFLOW));
            }
            else
            {
                depotEth[refundUser].locked[msg.sender].amount = 0;
                depotEth[refundUser].amount = depotEth[refundUser].amount.safeAdd248(refundAmount);
                emit LogLockDepositRefund(refundUser, refundAmount);
            }
        }

        return true;
    }

    /**
     * endorse
     * @dev : endorse (set to 0) locked deposit to a called smart contract
     *
     * msg.sender : smart contract of parent smart contract
     */
    function endorse(uint248 amount, address user) external returns (bool) {

        if(depotEth[user].locked[msg.sender].amount == amount){
            depotEth[user].locked[msg.sender].amount = 0;
            emit LogEndorse(user, amount);
            return true;
        }
        return false;
    }

    /*** Withdrawal ***/

    /**
     * withdrawal
     * @dev : The user can ask a withdrawal
     */

    function withdrawal(uint248 amount) public {

        if(amount == 0){
            emit LogError(uint8(Errors.WITHDRAWAL_ZERO_AMOUNT));
            return;
        }

        if(!depotEth[msg.sender].isValue){
            emit LogError(uint8(Errors.WITHDRAWAL_DEPOT_NOT_FOUND));
            return;
        }

        if (depotEth[msg.sender].amount < amount) {
            emit LogError(uint8(Errors.WITHDRAWAL_DEPOT_AMOUNT_TOO_LOW));
            return;
        }

        depotEth[msg.sender].amount = depotEth[msg.sender].amount.safeSub248(amount);
        emit LogWithdrawal(msg.sender, amount);
    }

    /**
     * addWithdrawalVoucher
     * @dev the WithdrawalVoucher is calculated in oracle
     */
    function addWithdrawalVoucher(
    address user,
    bytes h
    ) public isOracle
    {
        if(depotEth[user].withdrawalVoucher[h] != 0){
            emit LogError(uint8(Errors.WITHDRAWAL_VOUCHER_ALREADY_ADDED));
            return;
        }

        depotEth[user].withdrawalVoucher[h] = uint16(depotEth[user].withdrawalVoucherList.push(h) - 1);
        emit LogAddWithdrawalVoucher(user, h);
    }

    /**
     * Get available deposit for a user
     */
    function getDepotEthUserAmount(address user)
    public
    view
    returns(uint248 amount)
    {
        return depotEth[user].amount;
    }

    /**
     * Get length of withdrawal voucher list
     */
    function getUserWithdrawalVoucherLength()
    public
    view
    returns(uint16 length)
    {
        return uint16(depotEth[msg.sender].withdrawalVoucherList.length);
    }


    /**
     * Get Withdrawal voucher at index
     */
    function getWithdrawalVoucherAtIndex(uint16 index)
    public
    view
    returns (bytes h)
    {
        return depotEth[msg.sender].withdrawalVoucherList[index];
    }

    /**
     * Get index of a withdrawal voucher
     */
    function getWithdrawalVoucherIndex(address user, bytes h)
    public
    view
    returns (uint16)
    {
        return depotEth[user].withdrawalVoucher[h];
    }

    /**
     * Remove withdrawal voucher by replacing the index of withdrawal voucher by the last index in withdrawal voucher list
     */
    function removeWithdrawalVoucher(address user, bytes h)
    public
    isOracle
    {
        uint16 indexToDelete = depotEth[user].withdrawalVoucher[h];
        uint16 length = uint16(depotEth[user].withdrawalVoucherList.length);
        if(length > 1)
        {
            bytes memory hashToMove = depotEth[user].withdrawalVoucherList[length - 1];
            depotEth[user].withdrawalVoucherList[indexToDelete] = hashToMove;
            depotEth[user].withdrawalVoucher[hashToMove] = indexToDelete;
        }
        depotEth[user].withdrawalVoucherList.length --;

        emit LogWithdrawalVoucherHaveBeenRemoved(user, h);
    }

    /*** View ***/

    function getDepotEthListCount() public constant returns(uint16 depotEthLength)
    {
        return uint16(depotEthList.length);
    }

    function getDepotEthLockedCountForUser(address user) public constant returns (uint16 depotEthLockCount){
        return uint16(depotEth[user].lockedList.length);
    }

    function getDepotEthLockedAmountForUserByAddress(address user,address addressLocked) public constant returns (uint248 amountLocked){
        return depotEth[user].locked[addressLocked].amount;
    }

    function getDepotEthLockedDataForUserByIndex(address user,uint248 index) public constant returns (address addressLocked, uint248 amountLocked){
        addressLocked = depotEth[user].lockedList[index];
        amountLocked = getDepotEthLockedAmountForUserByAddress(user, addressLocked);
    }
}

