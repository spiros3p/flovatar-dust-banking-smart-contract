// import Flovatar from "../contracts/lib/Flovatar.cdc"
// import NonFungibleToken from "../contracts/interfaces/NonFungibleToken.cdc"
import DustLender from "../contracts/DustLender.cdc"

transaction(flovatarId: UInt64, wallet: Address) {

  prepare(acct: AuthAccount) {
    DustLender.retrieveCollateralFromLoan(flovatarId: flovatarId, wallet: wallet)
  }

  execute {}
}