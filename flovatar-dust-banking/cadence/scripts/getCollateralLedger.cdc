import DustLender from "../contracts/DustLender.cdc"

pub fun main(): {Address: {UInt64: DustLender.CollateralizedFlovatar}} {
  return DustLender.collateralLedger
}
