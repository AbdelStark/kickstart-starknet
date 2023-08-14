//! Contract to create markets.

// *************************************************************************
//                                  IMPORTS
// *************************************************************************

// Core lib imports.
use starknet::ContractAddress;

#[starknet::interface]
trait IERC20<TState> {
    /// Returns the name of the token.
    fn name(self: @TState) -> felt252;
    /// Returns the symbol of the token, usually a shorter version of the name.
    fn symbol(self: @TState) -> felt252;
    /// Returns the number of decimals used to get its user representation.
    fn decimals(self: @TState) -> u8;
    /// Returns the total token supply.
    fn total_supply(self: @TState) -> u128;
    /// Returns the account balance of another account with address `account`.
    /// # Arguments
    /// * `account` - The address of the account to query.
    /// # Returns
    /// * The balance of `account`.
    fn balance_of(self: @TState, account: ContractAddress) -> u128;
    /// Returns the amount which `spender` is still allowed to withdraw from `owner`.
    /// # Arguments
    /// * `owner` - The address of the account owning tokens.
    /// * `spender` - The address of the account able to transfer the tokens.
    /// # Returns
    /// * Amount of remaining tokens allowed to spent.
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u128;
    /// Moves `amount` tokens from the caller's account to `recipient`.
    /// # Arguments
    /// * `recipient` - The address of the recipient.
    /// * `amount` - The amount of tokens to transfer.
    /// # Returns
    /// * `true` if the transfer succeeded, `false` otherwise.
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u128) -> bool;
    /// Moves `amount` tokens from `sender` to `recipient`.
    /// # Arguments
    /// * `sender` - The address of the sender.
    /// * `recipient` - The address of the recipient.
    /// * `amount` - The amount of tokens to transfer.
    /// # Returns
    /// * `true` if the transfer succeeded, `false` otherwise.
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u128
    ) -> bool;
    /// Increases `amount` tokens allowance to `spender`.
    /// # Arguments
    /// * `spender` - The address of the account able to transfer the tokens.
    /// * `amount` - The amount of tokens to increase the allowance by.
    /// # Returns
    /// * `true` if the increase succeeded, `false` otherwise.
    fn approve(ref self: TState, spender: ContractAddress, amount: u128) -> bool;
}


#[starknet::contract]
mod ERC20 {
    // *************************************************************************
    //                               IMPORTS
    // *************************************************************************

    // Core lib imports.
    use integer::BoundedInt;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    // Local imports.
    use super::IERC20;

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {
        _name: felt252,
        _symbol: felt252,
        _total_supply: u128,
        _balances: LegacyMap<ContractAddress, u128>,
        _allowances: LegacyMap<(ContractAddress, ContractAddress), u128>,
    }

    // *************************************************************************
    //                              EVENTS
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u128
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u128
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        initial_supply: u128,
        recipient: ContractAddress
    ) {
        self.initializer(name, symbol);
        self._mint(recipient, initial_supply);
    }

    // *************************************************************************
    //                          EXTERNAL FUNCTIONS
    // *************************************************************************

    #[external(v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self._name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self._symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            18
        }

        fn total_supply(self: @ContractState) -> u128 {
            self._total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u128 {
            self._balances.read(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u128 {
            self._allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u128) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u128
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u128) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
        }
    }

    #[external(v0)]
    fn increase_allowance(
        ref self: ContractState, spender: ContractAddress, added_value: u128
    ) -> bool {
        self._increase_allowance(spender, added_value)
    }

    #[external(v0)]
    fn increaseAllowance(
        ref self: ContractState, spender: ContractAddress, addedValue: u128
    ) -> bool {
        increase_allowance(ref self, spender, addedValue)
    }

    #[external(v0)]
    fn decrease_allowance(
        ref self: ContractState, spender: ContractAddress, subtracted_value: u128
    ) -> bool {
        self._decrease_allowance(spender, subtracted_value)
    }

    #[external(v0)]
    fn decreaseAllowance(
        ref self: ContractState, spender: ContractAddress, subtractedValue: u128
    ) -> bool {
        decrease_allowance(ref self, spender, subtractedValue)
    }

    // *************************************************************************
    //                          INTERNAL FUNCTIONS
    // *************************************************************************

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState, name_: felt252, symbol_: felt252) {
            self._name.write(name_);
            self._symbol.write(symbol_);
        }

        fn _increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u128
        ) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, self._allowances.read((caller, spender)) + added_value);
            true
        }

        fn _decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u128
        ) -> bool {
            let caller = get_caller_address();
            self
                ._approve(
                    caller, spender, self._allowances.read((caller, spender)) - subtracted_value
                );
            true
        }

        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u128) {
            assert(!recipient.is_zero(), 'ERC20: mint to 0');
            self._total_supply.write(self._total_supply.read() + amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            self.emit(Transfer { from: Zeroable::zero(), to: recipient, value: amount });
        }

        fn _burn(ref self: ContractState, account: ContractAddress, amount: u128) {
            assert(!account.is_zero(), 'ERC20: burn from 0');
            self._total_supply.write(self._total_supply.read() - amount);
            self._balances.write(account, self._balances.read(account) - amount);
            self.emit(Transfer { from: account, to: Zeroable::zero(), value: amount });
        }

        fn _approve(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u128
        ) {
            assert(!owner.is_zero(), 'ERC20: approve from 0');
            assert(!spender.is_zero(), 'ERC20: approve to 0');
            self._allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u128
        ) {
            assert(!sender.is_zero(), 'ERC20: transfer from 0');
            assert(!recipient.is_zero(), 'ERC20: transfer to 0');
            self._balances.write(sender, self._balances.read(sender) - amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn _spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u128
        ) {
            let current_allowance = self._allowances.read((owner, spender));
            if current_allowance != BoundedInt::max() {
                self._approve(owner, spender, current_allowance - amount);
            }
        }
    }
}
