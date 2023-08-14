// *************************************************************************
//                                  IMPORTS
// *************************************************************************

// Core lib imports.
use array::ArrayTrait;
use result::ResultTrait;
use option::OptionTrait;
use traits::{TryInto, Into};
use starknet::{
    ContractAddress, get_caller_address, contract_address_const,
    ClassHash,
};
use cheatcodes::PreparedContract;

// Local imports.
use {{project_name}}::token::erc20::{IERC20SafeDispatcher, IERC20SafeDispatcherTrait};

#[test]
fn given_normal_conditions_when_transfer_then_balances_are_updated() {
    // *********************************************************************************************
    // *                              SETUP TEST ENVIRONMENT                                       *
    // *********************************************************************************************
    let name = 'Test Token';
    let symbol = 'TT';
    let initial_supply = 1000;
    let (caller, erc20) = setup_test_environment(name, symbol, initial_supply);

    // *********************************************************************************************
    // *                              TEST LOGIC                                                   *
    // *********************************************************************************************
    let recipient = contract_address_const::<'recipient'>();
    
    // Get the initial balances of the caller and the recipient.
    let initial_caller_balance = erc20.balance_of(caller).unwrap();
    let initial_recipient_balance = erc20.balance_of(recipient).unwrap();

    // Assert that the initial balances are correct.
    assert(initial_caller_balance == initial_supply, 'wrong supply');
    assert(initial_recipient_balance == 0, 'wrong initial recipient balance');

    // Transfer 100 tokens from the caller to the recipient.
    erc20.transfer(recipient, 100).unwrap();

    // Get the final balances of the caller and the recipient.
    let final_caller_balance = erc20.balance_of(caller).unwrap();
    let final_recipient_balance = erc20.balance_of(recipient).unwrap();

    // Assert that the final balances are correct.
    assert(final_caller_balance == initial_supply - 100, 'wrong final caller balance');
    assert(final_recipient_balance == 100, 'wrong final recipient balance');

    // *********************************************************************************************
    // *                              TEARDOWN TEST ENVIRONMENT                                    *
    // *********************************************************************************************
    teardown_test_environment();
}

/// Utility function to setup the test environment.
fn setup_test_environment(name: felt252, symbol: felt252, initial_supply: u128) -> (
    // The address of the caller
    ContractAddress,
    // An interface to interact with the `ERC20` contract.
    IERC20SafeDispatcher,
){
    let caller = contract_address_const::<'caller'>();
    // Get the caller address.
    // Deploy the ERC20 contract.
    let erc20_address = deploy_erc20(name, symbol, initial_supply, caller);
    // Get an interface to interact with the ERC20 contract.
    let erc20 = IERC20SafeDispatcher{contract_address: erc20_address};

    // Prank the caller.
    start_prank(erc20_address, caller);
    
    (caller, erc20)
}

/// Utility function to deploy an ERC20 token.
/// # Arguments
/// * `name` - The name of the token.
/// * `symbol` - The symbol of the token.
/// * `initial_supply` - The initial supply of the token.
/// * `recipient` - The recipient of the initial supply.
/// # Returns
/// The address of the deployed ERC20 token.
fn deploy_erc20(name: felt252, symbol: felt252, initial_supply: u128, recipient: ContractAddress) -> ContractAddress {
    let class_hash = declare('ERC20');
    let mut constructor_calldata = array![];
    constructor_calldata.append(name);
    constructor_calldata.append(symbol);
    constructor_calldata.append(initial_supply.into());
    constructor_calldata.append(recipient.into());
    let prepared = PreparedContract {
        class_hash: class_hash, constructor_calldata: @constructor_calldata
    };
    deploy(prepared).unwrap()
}

/// Utility function to teardown the test environment.
fn teardown_test_environment() {}