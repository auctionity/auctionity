# Auctionity

You can find the code of our current smart contracts running on rinkeby or on Auctionity private blockchain.



## Status and Error codes

Find the list of possible error code and their meaning :

### AuctionityTreasurerEth

| ErrorId | SC constant                      | Description                                              |
| ------- | -------------------------------- | -------------------------------------------------------- |
| 0       | LOCK_DEPOSIT_OVERFLOW            | Refund amount of previous bidder is over uint248.        |
| 1       | WITHDRAWAL_ZERO_AMOUNT           | Amount of withdrawal requested is zero.                  |
| 2       | WITHDRAWAL_DEPOT_NOT_FOUND       | No deposit found for withdrawal requested.               |
| 3       | WITHDRAWAL_DEPOT_AMOUNT_TOO_LOW  | Not enouth amount into deposit for withdrawal requested. |
| 4       | WITHDRAWAL_VOUCHER_ALREADY_ADDED | Withdrawal voucher has been already added.               |

### AuctionityAuctionEngPgEth

| StatusId | SC constant         | Description                                  |
| -------- | ------------------- | -------------------------------------------- |
| 0        | ACCEPTED            | Bid is accepted.                             |
| 1        | AMOUNT_TOO_LOW      | Amount of bid is under minimal amount.       |
| 2        | LOCK_DEPOSIT_FAILED | Deposit amount is lower than bidding amount. |

| ErrorId | SC constant                       | Description                                                  |
| ------- | --------------------------------- | ------------------------------------------------------------ |
| 0       | INVALID_DATE_AT_CONTRACT_CREATION | End date of auction must be in the future and start date must be before end date. |
| 1       | AUCTION_OWNER_CAN_NOT_BID         | The owner of an auction cannott bid on this auction.         |
| 2       | AUCTION_IS_NOT_STARTED_YET        | The auction is not started yed.                              |
| 3       | AUCTION_IS_ALREADY_ENDED          | The auction has already ended.                               |
| 4       | AUCTION_IS_NOT_FINISHED_YET       | The auction is not ended yet.                                |
| 5       | END_IS_ALREADY_CALLED             | The call of end function has already been submited.          |
| 6       | END_ENDORSE_FAILED                | Failed to endorse the bidder deposit at the end of the auction. |

### AuctionityDepositEth

| ErrorId | SC constant                              | Description                                    |
| ------- | ---------------------------------------- | ---------------------------------------------- |
| 0       | DEPOSED_ADD_DATA_FAILED                  | The total of deposit amount is over uint248.   |
| 1       | WITHDRAWAL_VOUCHER_DEPOT_NOT_FOUND       | No deposit has been found.                     |
| 2       | WITHDRAWAL_VOUCHER_DEPOT_AMOUNT_TOO_LOW  | Deposit amount is under requested amount.      |
| 3       | WITHDRAWAL_VOUCHER_ALREADY_SUBMITED      | Withdrawal voucher has already been submitted. |
| 4       | WITHDRAWAL_VOUCHER_INVALID_SIGNATURE     | The signer of voucher is not oracle address.   |
| 5       | WITHDRAWAL_VOUCHER_ETH_TRANSFERT_FAILED  | Transfer failed.                               |
| 6       | AUCTION_END_VOUCHER_DEPOT_NOT_FOUND      | No deposit has been found.                     |
| 7       | AUCTION_END_VOUCHER_DEPOT_AMOUNT_TOO_LOW | Deposit amount is under requested amount.      |
| 8       | AUCTION_END_VOUCHER_ALREADY_SUBMITED     | AuctionEnd voucher has been found.             |
| 9       | AUCTION_END_VOUCHER_INVALID_SIGNATURE    | The signer of voucher is not oracle address.   |
| 10      | AUCTION_END_VOUCHER_ETH_TRANSFERT_FAILED | Transfer failed.                               |