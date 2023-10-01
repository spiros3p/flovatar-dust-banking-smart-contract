import DustLender from "../contracts/DustLender.cdc"
import FlovatarDustToken from "../contracts/lib/FlovatarDustToken.cdc"
import FungibleToken from "../contracts/interfaces/FungibleToken.cdc"

transaction(noOfDays: UInt64) {

  prepare(acct: AuthAccount) {
    let ref = acct.borrow<&DustLender.Administrator>(from: DustLender.AdminStoragePath) ?? panic("DustLender Admin resource was not found in the wallet")
    ref.changeMaxDaysOfLoan(noOfDays: noOfDays)
  }

  execute {}
}
