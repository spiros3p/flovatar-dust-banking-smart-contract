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
