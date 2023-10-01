// import DustLender from 0x1829e3193c654852
// import FlovatarDustToken from 0x9392a4a7c3f49a0b
// import Flovatar from 0x9392a4a7c3f49a0b
// import FungibleToken from 0x9a0766d93b6608b7
// import NonFungibleToken from 0x631e88ae7f1d7c20

import DustLender from "../contracts/DustLender.cdc"
import FlovatarDustToken from "../contracts/lib/FlovatarDustToken.cdc"
import FungibleToken from "../contracts/interfaces/FungibleToken.cdc"

transaction(amount: UFix64) {

  prepare(acct: AuthAccount) {
    let vault <- acct.borrow<&FlovatarDustToken.Vault{FungibleToken.Provider}>(from: FlovatarDustToken.VaultStoragePath)!.withdraw(amount: amount)
    DustLender.depositCapital(dustVault: <- vault)
  }

  execute {}
}
