import DustLender from "../contracts/DustLender.cdc"

pub fun main(wallet: Address): {UInt64: DustLender.CollateralizedFlovatar} {
  return DustLender.getUserEntries(wallet: wallet)
}
