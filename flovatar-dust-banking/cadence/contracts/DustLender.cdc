import Flovatar from "./lib/Flovatar.cdc"
import FlovatarDustToken from "./lib/FlovatarDustToken.cdc"
import FlovatarInbox from "./lib/FlovatarInbox.cdc"
import NonFungibleToken from "./interfaces/NonFungibleToken.cdc"
import FungibleToken from "./interfaces/FungibleToken.cdc"

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
    access(contract) let collateralLedger: {Address: {UInt64: CollateralizedFlovatar}}

    // /////////////////////////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////

    // /////////////////////////////////////////////////////////////////////
    // /////// EVENTS /////////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////
    access(all) event ContractInitialized()
    access(all) event CapitalDeposited(amount: UFix64)
    access(all) event CapitalWithdrawn(amount: UFix64, receiver: Address, capital: UFix64)
    access(all) event CollateralDeposited(from: Address, flovatarId: UInt64, entry: CollateralizedFlovatar?)
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
        self.funDepositDustToUser(vault: <- vaultDust, receiver: wallet)
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

    access(self) fun registerLoanToLedger(wallet: Address, dustAmount: UFix64, flovatarId: UInt64): CollateralizedFlovatar? {
        //pre {
        //    !self.collateralLedger[wallet].containsKey(flovatarId) : "Ledger already contains an entry for this Flovatar!"
        //}
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

    access(self) fun removeFromLedger(wallet: Address, flovatarId: UInt64){
        post {
            !self.collateralLedger[wallet]!.containsKey(flovatarId) : "Ledger still contains the entry for this Flovatar!"
        }
        self.collateralLedger[wallet]!.remove(key: flovatarId)
    }

    access(contract) fun funDepositDustToUser(vault: @FungibleToken.Vault, receiver: Address) {
        let vaultUser = getAccount(receiver).getCapability(FlovatarDustToken.VaultReceiverPath)
                                        .borrow<&FlovatarDustToken.Vault{FungibleToken.Receiver}>() 
                                        ?? panic("User's vault was not found")
        vaultUser.deposit(from: <- vault)           
    }

    access(contract) fun depositFlovatarInThisWalletCollection(flov: @Flovatar.NFT) {
        self.account.borrow<&Flovatar.Collection{NonFungibleToken.Receiver}>(from: Flovatar.CollectionStoragePath)!.deposit(token: <- flov)
    }

    access(contract) fun witdrawDustFromThisWalletVault(amount: UFix64): @FungibleToken.Vault {
        return <- self.account.borrow<&FlovatarDustToken.Vault{FungibleToken.Provider}>(from: FlovatarDustToken.VaultStoragePath)!.withdraw(amount: amount)
    }
    // /////////////////////////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////

    // /////////////////////////////////////////////////////////////////////
    // /////// RESOURCES ///////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////
    access(all) resource Administrator {
        access(all) fun changeRate(newRate: UFix64) {
            pre {
                UFix64(0.0) < newRate : "Rate must be between 0.0 and 1.0"
                newRate < UFix64(1.0) : "Rate must be between 0.0 and 1.0"
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
            DustLender.funDepositDustToUser(vault: <- vault, receiver: receiver)
        }
    }
    // /////////////////////////////////////////////////////////////////////
    // /////////////////////////////////////////////////////////////////////


    // depositCollateral (flovatar, days, userCollectionCap/wallet)
    //// FlovatarInbox.claimFlovatarCommunityDust
    //// flovatarScore = Flovatar.getFlovatarRarityScore(address: address, flovatarId: id)
    //// dustPerDay = (3.0 + flovatarScore) * FlovatarInbox.dustPerDayPerScore
    //// move dust out of this accounts vault, into depositor's vault

    // calculateAmountToHarvest (flovatar_id)
    //// FlovatarInbox.getClaimableFlovatarCommunityDust

    // withdrawCollateral (flovatar_id)
    //// maybe harvest Dust amount on withdrawal 
    //// FlovatarInbox.getClaimableFlovatarCommunityDust
    //// get the userCollectionCap from the dictionary and 
    //// deposit the flovatar there

    // harvestDust (flovatar_id, )

    // dict => { Address: CollateralStruct[] }

    // getOwnerVaultCap(wallet): return owner's Vault public cap to deposit Dust

    // getOwnerCollectionCap(wallet): return owner's collection public cap

/*     
    // struct
        CollateralStruct {
            flovatar_Id
            // unlockTime
            // userCollectionCap
            wallet
            pawnedAmount = 500
        } 
*/
    
    init() {
        // open for business
        self.lendingIsActive = true
        self.serviceFee = 0.05
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