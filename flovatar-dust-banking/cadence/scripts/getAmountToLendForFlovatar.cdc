import FlovatarInbox from "../contracts/lib/FlovatarInbox.cdc"
import DustLender from "../contracts/DustLender.cdc"

pub fun main(days: UInt64, wallet: Address, flovatarId: UInt64): UFix64 {
    let info: FlovatarInbox.ClaimableDust = FlovatarInbox.getClaimableFlovatarCommunityDust(id: flovatarId, address: wallet) 
                                                    ?? panic("Claimable dust info for flovatar not found!")
    let dustPerDay = info.amount / UFix64(info.days)
    return dustPerDay * UFix64(days) * (1.0 - DustLender.getCurrentServiceFee()) 
}
