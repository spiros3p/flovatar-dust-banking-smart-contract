import DustLender from "../contracts/DustLender.cdc"
import FlovatarDustToken from "../contracts/lib/FlovatarDustToken.cdc"
import FungibleToken from "../contracts/interfaces/FungibleToken.cdc"

transaction(amount: UFix64, receiver: Address) {

  prepare(acct: AuthAccount) {
    let ref = acct.borrow<&DustLender.Administrator>(from: DustLender.AdminStoragePath) ?? panic("DustLender Admin resource was not found in the wallet")
    ref.withdrawCapitalToReceiver(amount: amount, receiver: receiver)
  }

  execute {}
}
