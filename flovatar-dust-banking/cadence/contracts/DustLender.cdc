import Flovatar from "./lib/Flovatar.cdc"
import FlovatarDustToken from "./lib/FlovatarDustToken.cdc"
import FlovatarInbox from "./lib/FlovatarInbox.cdc"
import NonFungibleToken from "./interfaces/NonFungibleToken.cdc"
import FungibleToken from "./interfaces/FungibleToken.cdc"

/* 
    DustLending - v0.1
    by Spiros3p

    This is a smart contract to offer a lending service for the Flovatar NFT project.
    A Flovatar owner can send the NFT to this contract using the  method and
    receive instantly the Dust amount based on the flovatars dust per day generation
    and the user's number of days selection.
    The flovatar NFT is kept in the Flovatar collection of the wallet that has deployed this contract
    and someone can retrieve it back to the owner's wallet after the flovatar can collect the lent amount (+service fee).

    FLAWS:
    - the reason this contract needs to store the Flovatar NFTs in a Flovatar.Collection 
    in the storage path, is due to the Flovatar.getFlovatarRarityScore() method which is called 
    in FlovatarInbox.claimFlovatarCommunityDust() to claim daily dust
    - anyone can claim the dust for a Flovatar NFT held in this wallet. Sadly, this v0.1 of the contract, 
    does not take this into consideration when someone will try to retrieve a collateral. Meaning the contract will still
    have to check, whether it can claim the owed amount before sending the flovatar back.
    - the deployer of the contract can withdraw the held NFTs
        - a potential solution is to keep the NFTs in custom resource collection that blocks withdrawals, 
        BUT that would break the DUST collection due to Flovatar.getFlovatarRarityScore() method
        that looks for the NFT in the wallet's collection public path (as defined by the Flovatar contract)
        - a potential solution for that would be for the user trying to retrieve the collateral 
        to pass private cap to withdraw Dust from their vault, after sending the flovatar back 
        and collecting the Dust in their wallet. (if all these actions can be performed in one go)

    POTENTIAL UPGRADES
    - solving the above flaws
    - be abble to collect Dust mid way through the loan
        - that would help with liquidity of the contract

    CONTRACT EXTENSION
    - dust supply contract (more info later)
 */


access(all) contract DustLender {

    // /////////////////////////////////////////////////////////////////////
    // /////// VARIABLES ///////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////
    // path to store Admin resource
    access(all) let AdminStoragePath: StoragePath
    // the fee for the service
    access(all) var serviceFee: UFix64
    // boolean var to toggle lending on and off
    access(all) var lendingIsActive: Bool
    // max number of days that loans can be given
    access(all) var maxDaysOfLoan: UInt64
    // dictionary to keep track of collaterals and lending - ledger
    access(account) let collateralLedger: {Address: {UInt64: CollateralizedFlovatar}}

    // /////////////////////////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////

    // /////////////////////////////////////////////////////////////////////
    // /////// EVENTS /////////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////
    access(all) event ContractInitialized()
    access(all) event CapitalDeposited(amount: UFix64)
    access(all) event CapitalWithdrawn(amount: UFix64, receiver: Address, capital: UFix64)
    access(all) event CollateralDeposited(from: Address, flovatarId: UInt64, entry: CollateralizedFlovatar?)
    access(all) event CollateralRetrieved(wallet: Address, flovatarId: UInt64, entry: CollateralizedFlovatar?)
    // /////////////////////////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////

    // /////////////////////////////////////////////////////////////////////
    // /////// STRUCTS /////////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////
    access(all) struct CollateralizedFlovatar{
        access(all) let dustAmountToClaim: UFix64
        access(all) let flovatarId: UInt64
        access(all) let wallet: Address
        access(all) let timestamp: UFix64
        init(dustAmountToClaim: UFix64, flovatarId: UInt64, wallet: Address, timestamp: UFix64){
            self.dustAmountToClaim = dustAmountToClaim
            self.flovatarId = flovatarId
            self.wallet = wallet
            self.timestamp = timestamp
        }
    }
    // /////////////////////////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////

    // /////////////////////////////////////////////////////////////////////
    // /////// FUNCTIONS ///////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////
    // return Total amount of Dust available for lending
    access(all) fun getCollateralVaultDustBalance(): UFix64 {
        let vaultCap = self.account.getCapability(FlovatarDustToken.VaultBalancePath)
        return vaultCap.borrow<&FlovatarDustToken.Vault{FungibleToken.Balance}>()!.balance
    }

    // fetch the current service fee
    access(all) fun getCurrentServiceFee(): UFix64 {
        return self.serviceFee
    }

    // fetch the current max days of loaning
    access(all) fun getCurrentMaxDaysOfLoan(): UInt64 {
        return self.maxDaysOfLoan
    }

    // feth a wallets taken loans info
    access(all) fun getUserEntries(wallet: Address): {UInt64: CollateralizedFlovatar} {
        return self.collateralLedger[wallet] ?? panic("No entry found for this wallet")
    }

    // method to deposit Dust in the wallet's vault for lending
    access(all) fun depositCapital(dustVault: @FungibleToken.Vault) {
        pre {
            self.serviceFee >= UFix64(0.0) : "Service fee must be set first!"
        }
        let vault <- dustVault as! @FlovatarDustToken.Vault
        emit CapitalDeposited(amount: vault.balance)
        self.account.borrow<&FlovatarDustToken.Vault{FungibleToken.Receiver}>(from: FlovatarDustToken.VaultStoragePath)!.deposit(from: <- vault)
    }

    // the main method users are using to send a Flovatar and receive Dust
    // 1. total dust generated for the desired days is calculated
    // 2. dust amount minus the fee, is transfered to the sender's wallet
    // 3. info is registered in the collateralLedger dict
    // 4. flovatar goes into the flovatar.collection of this contract's wallet
    access(all) fun depositCollateralForLoan(
        flovatar: @NonFungibleToken.NFT,
        daysOfLoan: UInt64,
        wallet: Address
    ) {
        pre {
            self.serviceFee >= UFix64(0.0) : "Service fee must be set first!"
            self.lendingIsActive : "Currently lending is on hold!"
            daysOfLoan <= self.maxDaysOfLoan : "Try a loan for less days!"
        }
        let flovatar <- flovatar as! @Flovatar.NFT
        let flovatarId = flovatar.id
        let flovatarScore = flovatar.getRarityScore()
        let dustPerDayPerScore = FlovatarInbox.getDustPerDayPerScore()
        let dustPerDay = (3.0 + flovatarScore) * dustPerDayPerScore
        // 1.
        let dustAmountToClaim = UFix64(daysOfLoan) * dustPerDay 
        // 2.
        let dustAmountToLend = dustAmountToClaim * ( 1.0 - self.serviceFee )
        let vaultDust <- self.witdrawDustFromThisWalletVault(amount: dustAmountToLend)
        self.transferDustToUser(vault: <- vaultDust, receiver: wallet)
        // 3.
        let ledgerEntry = self.registerLoanToLedger(
            wallet: wallet, 
            dustAmount: dustAmountToClaim, 
            flovatarId: flovatarId
        )
        // 4.
        self.depositFlovatarInThisWalletCollection(flov: <- flovatar)
        emit CollateralDeposited(from: wallet, flovatarId: flovatarId, entry: ledgerEntry)
    }

    // the other main function that users will use to get back their flovatar 
    // when the loaned amount (plus fee) has been collected
    // 1. find the entry 
    // 2. check the collectable dust amount of the flovatar
    // 3. if it is more than the amount owned proceed, otherwise break.
    // 4. collect the dust amount
    // 5. send the flovatar back and the extra dust collected (if there is any)
    // 6. remove entry from the ledger
    access(all) fun retrieveCollateralFromLoan(
        flovatarId: UInt64, 
        wallet: Address
    ) {
        // 1.
        let walletEntries = &self.collateralLedger[wallet] as &{UInt64: CollateralizedFlovatar}? ?? panic("There is no entry of this wallet for a loan!")
        let ledgerEntry = &walletEntries[flovatarId] as &CollateralizedFlovatar? ?? panic("This wallet address has no loan entry for this flovatar ID!")
        // 2.
        let claimableDustInfo: FlovatarInbox.ClaimableDust = FlovatarInbox.getClaimableFlovatarCommunityDust(id: flovatarId, address: self.account.address) 
                                                            ?? panic("Could not fetch information from FlovatarInbox")
        // 3.
        if claimableDustInfo.amount < ledgerEntry.dustAmountToClaim {
            panic("Dust amount owed cannot be collected yet! Try again in a few days.")
        }
        let addionalDust = claimableDustInfo.amount - ledgerEntry.dustAmountToClaim
        // 4.
        FlovatarInbox.claimFlovatarCommunityDust(id: flovatarId, address: self.account.address)
        // 5.
        let flovatar <- self.withdrawFlovatarFromThisWallet(id: flovatarId)
        let collectionRef = getAccount(wallet).getCapability(Flovatar.CollectionPublicPath).borrow<&Flovatar.Collection{NonFungibleToken.Receiver}>() ?? panic("User's flovatar collection was not found")
        collectionRef.deposit(token: <- flovatar)
        if addionalDust > 0.0 {
            let vaultRef = getAccount(wallet).getCapability(FlovatarDustToken.VaultReceiverPath).borrow<&FlovatarDustToken.Vault{FungibleToken.Receiver}>() ?? panic("User's Dust vault was not found")
            vaultRef.deposit(from: <- self.witdrawDustFromThisWalletVault(amount: addionalDust))
        }
        // 6. 
        let entry = self.removeFromLedger(wallet: wallet, flovatarId: flovatarId)

        emit CollateralRetrieved(wallet: wallet, flovatarId: flovatarId, entry: entry)
    }

    access(contract) fun transferDustToUser(vault: @FungibleToken.Vault, receiver: Address) {
        let vaultRefUser = getAccount(receiver).getCapability(FlovatarDustToken.VaultReceiverPath)
                                        .borrow<&FlovatarDustToken.Vault{FungibleToken.Receiver}>() 
                                        ?? panic("User's vault was not found")
        vaultRefUser.deposit(from: <- vault)           
    }

    access(contract) fun depositFlovatarInThisWalletCollection(flov: @Flovatar.NFT) {
        self.account.borrow<&Flovatar.Collection{NonFungibleToken.Receiver}>(from: Flovatar.CollectionStoragePath)!.deposit(token: <- flov)
    }

    access(contract) fun witdrawDustFromThisWalletVault(amount: UFix64): @FungibleToken.Vault {
        return <- self.account.borrow<&FlovatarDustToken.Vault{FungibleToken.Provider}>(from: FlovatarDustToken.VaultStoragePath)!.withdraw(amount: amount)
    }

    access(self) fun withdrawFlovatarFromThisWallet(id: UInt64): @NonFungibleToken.NFT {
        return <- self.account.borrow<&Flovatar.Collection{NonFungibleToken.Provider}>(from: Flovatar.CollectionStoragePath)!.withdraw(withdrawID: id)
    }

    access(self) fun registerLoanToLedger(wallet: Address, dustAmount: UFix64, flovatarId: UInt64): CollateralizedFlovatar? {
        let ledgerEntry = CollateralizedFlovatar(
            dustAmountToClaim: dustAmount,
            flovatarId: flovatarId,
            wallet: wallet,
            timestamp: getCurrentBlock().timestamp
        )
        if self.collateralLedger.containsKey(wallet) {
            return self.collateralLedger[wallet]!.insert(key: flovatarId, ledgerEntry)

        } else {
            self.collateralLedger.insert(key: wallet, {})
            return self.collateralLedger[wallet]!.insert(key: flovatarId, ledgerEntry)
        }
    }

    access(self) fun removeFromLedger(wallet: Address, flovatarId: UInt64): CollateralizedFlovatar? {
        post {
            !self.collateralLedger[wallet]!.containsKey(flovatarId) : "Ledger still contains the entry for this Flovatar!"
        }
        return self.collateralLedger[wallet]!.remove(key: flovatarId)
    }
    // /////////////////////////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////

    // /////////////////////////////////////////////////////////////////////
    // /////// RESOURCES ///////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////
    access(all) resource Administrator {
        access(all) fun changeRate(newRate: UFix64) {
            pre {
                UFix64(0.0) < newRate : "Fee rate must be bigger than 0.00"
                newRate < UFix64(1.0) : "Fee rate must be less than 1.00"
            }
            DustLender.serviceFee = newRate
        }

        access(all) fun toggleLendingIsActive() {
            pre {
                DustLender.serviceFee >= UFix64(0.0) : "Service fee must be set first!"
            }
            DustLender.lendingIsActive = !DustLender.lendingIsActive
        }

        access(all) fun changeMaxDaysOfLoan(noOfDays: UInt64) {
            pre {
                noOfDays > 0 : "Max days of loan cannot be 0 or negative"
            }
            DustLender.maxDaysOfLoan = noOfDays
        }

        access(all) fun withdrawCapitalToReceiver(amount: UFix64, receiver: Address) {
            pre {
                amount <= DustLender.getCollateralVaultDustBalance() : "Not enough dust in the vault to withdraw"
            }
            let vault <- DustLender.witdrawDustFromThisWalletVault(amount: amount)
            let capital = DustLender.getCollateralVaultDustBalance()
            emit CapitalWithdrawn(amount: vault.balance, receiver: receiver, capital: capital)
            DustLender.transferDustToUser(vault: <- vault, receiver: receiver)
        }
    }
    // /////////////////////////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////

    // calculateAmountToHarvest (flovatar_id)
    //// FlovatarInbox.getClaimableFlovatarCommunityDust

    // withdrawCollateral (flovatar_id)
    //// maybe harvest Dust amount on withdrawal 
    //// FlovatarInbox.getClaimableFlovatarCommunityDust
    //// get the userCollectionCap from the dictionary and 
    //// deposit the flovatar there
    // getClaimableFlovatarCommunityDust

    // harvestDust (flovatar_id, )

    init() {
        // open for business
        self.lendingIsActive = true
        self.serviceFee = 0.05 // 5%
        self.maxDaysOfLoan = 15
        self.collateralLedger = {}

        // define admin storage path
        self.AdminStoragePath = /storage/DustLenderAdmin
        // create and save the admin resource
        self.account.save(<- create Administrator(), to: self.AdminStoragePath)

        // init Flovatar Collection - to store deposited flovatars
        self.account.save<@NonFungibleToken.Collection>(
            <- Flovatar.createEmptyCollection(), 
            to: Flovatar.CollectionStoragePath
        )
        // link to public path
        self.account.link<&Flovatar.Collection{Flovatar.CollectionPublic, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}>(
            Flovatar.CollectionPublicPath, 
            target: Flovatar.CollectionStoragePath
        )

        // init Dust Vault - to lend out Dust from and harvest 
        self.account.save<@FlovatarDustToken.Vault>(<- FlovatarDustToken.createEmptyVault(),
                             to: FlovatarDustToken.VaultStoragePath)
        // Create a public capability to the stored Vault that only exposes
        // the `deposit` method through the `Receiver` interface
        self.account.link<&FlovatarDustToken.Vault{FungibleToken.Receiver}>(
            FlovatarDustToken.VaultReceiverPath,
            target: FlovatarDustToken.VaultStoragePath
        )
        // Create a public capability to the stored Vault that only exposes
        // the `balance` field through the `Balance` interface
        self.account.link<&FlovatarDustToken.Vault{FungibleToken.Balance}>(
            FlovatarDustToken.VaultBalancePath,
            target: FlovatarDustToken.VaultStoragePath
        )

        emit ContractInitialized()
    }
}