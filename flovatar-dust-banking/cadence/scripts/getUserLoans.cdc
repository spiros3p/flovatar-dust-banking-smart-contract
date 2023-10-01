// import DustLender from 0x1829e3193c654852
// import FlovatarDustToken from 0x9392a4a7c3f49a0b
// import Flovatar from 0x9392a4a7c3f49a0b
// import FungibleToken from 0x9a0766d93b6608b7
// import NonFungibleToken from 0x631e88ae7f1d7c20

import DustLender from "../contracts/DustLender.cdc"

pub fun main(wallet: Address): {UInt64: DustLender.CollateralizedFlovatar} {
  return DustLender.getUserEntries(wallet: wallet)
}
