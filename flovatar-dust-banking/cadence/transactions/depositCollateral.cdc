import DustLender from "../contracts/DustLender.cdc"
import Flovatar from "../contracts/lib/Flovatar.cdc"
import NonFungibleToken from "../contracts/interfaces/NonFungibleToken.cdc"

transaction(flovatarId: UInt64, days: UInt64) {

  prepare(acct: AuthAccount) {
    let nft <- acct.borrow<&Flovatar.Collection{NonFungibleToken.Provider}>(from: Flovatar.CollectionStoragePath)!.withdraw(withdrawID: flovatarId)
    DustLender.depositCollateralForLoan(flovatar: <- nft, daysOfLoan: days, wallet: acct.address)
  }

  execute {}
}
