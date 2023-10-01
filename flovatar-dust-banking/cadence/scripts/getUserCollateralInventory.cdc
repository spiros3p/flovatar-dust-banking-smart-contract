// import FlovatarDustToken from 0x9392a4a7c3f49a0b
// import FungibleToken from 0x9a0766d93b6608b7
// import NonFungibleToken from 0x631e88ae7f1d7c20
// import FlovatarInbox from 0x9392a4a7c3f49a0b
// import Flovatar from 0x9392a4a7c3f49a0b
// import DustLender from 0x1829e3193c654852

import Flovatar from "../contracts/lib/Flovatar.cdc"
import FlovatarInbox from "../contracts/lib/FlovatarInbox.cdc"
import DustLender from "../contracts/DustLender.cdc"

pub let deployerWallet: Address = 0x1829e3193c654852

pub fun main(wallet: Address): [AnyStruct] {
  let collectionRef = getAccount(deployerWallet).getCapability(Flovatar.CollectionPublicPath).borrow<&Flovatar.Collection{Flovatar.CollectionPublic}>()!

  let entries = DustLender.getUserEntries(wallet: wallet)
  let flovs: [AnyStruct] = []

  for entry in entries.values {
    let id = entry.flovatarId
    let flov = collectionRef.borrowFlovatar(id: id)!
    let rarityScore = flov.getRarityScore()
    let that: {String: AnyStruct} = {
      "dailyDust": (3.0 + rarityScore) * FlovatarInbox.dustPerDayPerScore,
      "flovatar": flov,
      "claimableInfo": FlovatarInbox.getClaimableFlovatarCommunityDust(id: id, address: deployerWallet),
      "collateralInfo": entry
    }
    flovs.append(that)
  }
  return flovs
}