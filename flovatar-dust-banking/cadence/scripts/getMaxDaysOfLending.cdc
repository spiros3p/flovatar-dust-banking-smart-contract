import DustLender from "../contracts/DustLender.cdc"

pub fun main(): UInt64 {
  return DustLender.getCurrentMaxDaysOfLoan()
}