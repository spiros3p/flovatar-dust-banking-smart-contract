# FLOW Smart Contract
## Flovatar DustLender v0.1

This project is a submission for the September 2023 Cadence Competition    
https://flow.com/post/september-2023-cadence-competition

This smart contract aims to enhance the power of the Flovatar NFTs, a Flow blockchain that can be found here:    
https://flovatar.com/

MVP UI to access the smart contract's functions has been developed and deployed in the following github page
and can be accessed with a TestNet wallet:     
https://spiros3p.github.io/flovatar-dust-banking-app/

Flovatar NFTs, thanks to the Flovatar team's ideas, can collect daily the $DUST token, project's native token, a FT on the Flow blockchain.

What this smart contract offers is to supply $DUST to a user, that equals to a Flovatar's $DUST/day times the selected amount of days (minus a service fee), by transferring the Flovatar the smart contract's deployer's wallet as collateral.
After the selected days have passed and/or the loaned amount of $DUST can be collected for the flovatar by the smart contract, the user can retrieve their Flovatar NFT back.

How such a service could help the flovatar owners?
- Provide instant liquidity of $DUST to buy anything from Packs to Psyche Likee

If you have any questions, shoot me a message in the Flovatar discord (username: spiros3p)


### Contract Description

The smart contract has two main methods a) depositCollateralForLoan and b) retrieveCollateralFromLoan.
- **depositCollateralForLoan**
  - A user can call this method by providing a Flovatar.NFT and a number for the days that would put this Flovatar for collateral for the loan.
  - A user will then receive the desired $DUST amount
  - The amount is calculated based on the daily dust amount the flovatar can collect, the number of days the user selects and the service fee. (e.g., ammount = dailyDust * days * (1 - serviceFee))
  - The Flovatar NFT is kept in the contract's wallet, in the Flovatar.Collection resource located in the defined by the Flovatar contract, storage path. This is because the claim dust method looks for the Flovatar in that linked Public path.

- **retrieveCollateralFromLoan**
  - A user can call this method to try retrieving their collateral.
  - Flovatar must be able to collect the owned amount before returning to its owner
  - If the Flovatar can collect more than the amount owned, then the additional amount will be transferred to the owner's wallet as well
 
To keep track of the Lending action, **collateralLedger** dictionary is used. When a user retrieves their collateral the entry is deleted.
Example state of **collateralLedger**: 
`{ 0x01: { 1234: { dustAmountToClaim: 40, flovatarId: 1234, wallet: 0x01, timestamp: 12312455 } } }`

Lastly, an Admin resource is created and saved in the deployer's storage.
The following methods are available through this resource:
- changeRate: modify the service fee
- toggleLendingIsActive: turn the service on or off
- changeMaxDaysOfLoan: modify the max numbers of days able to get a loan for
- withdrawCapitalToReceiver: to transfer dust from the admin's wallet to the selected one
