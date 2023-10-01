// import DustLender from 0x1829e3193c654852
// import FlovatarDustToken from 0x9392a4a7c3f49a0b
// import Flovatar from 0x9392a4a7c3f49a0b
// import FungibleToken from 0x9a0766d93b6608b7
// import NonFungibleToken from 0x631e88ae7f1d7c20

import FlovatarInbox from "../contracts/lib/FlovatarInbox.cdc"
import DustLender from "../contracts/DustLender.cdc"

pub fun main(days: UInt64, wallet: Address, flovatarId: UInt64): UFix64 {
    let info: FlovatarInbox.ClaimableDust = FlovatarInbox.getClaimableFlovatarCommunityDust(id: flovatarId, address: wallet) 
                                                    ?? panic("Claimable dust info for flovatar not found!")
    let dustPerDay = info.amount / UFix64(info.days)
    return dustPerDay * UFix64(days) * (1.0 - DustLender.getCurrentServiceFee()) 
}
