import DustLender from "../contracts/DustLender.cdc"

pub fun main(): UFix64 {
  return DustLender.getCollateralVaultDustBalance()
}
