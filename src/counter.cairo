#[starknet::interface]
pub trait ICounter<T> {
    fn get_counter(self: @T) -> u32;
    fn increase_counter(ref self: T) -> ();
}

#[starknet::contract]
pub mod counter_contract {
    use super::ICounter;
    use starknet::ContractAddress;
    use kill_switch::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableComponent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;
    
    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, kill_switch: ContractAddress, initial_owner: ContractAddress) {
        self.ownable.initializer(initial_owner);

        self.counter.write(initial_value);
        self.kill_switch.write(kill_switch);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        #[flat]
        OwnableComponent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        value: u32,
    }

    #[abi(embed_v0)]
    impl CounterImpl of super::ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let kill_switch_dispatcher = IKillSwitchDispatcher { contract_address: self.kill_switch.read() };
            
            assert!(kill_switch_dispatcher.is_active() == false, "Kill Switch is active");

            let counter = self.counter.read();
            self.counter.write(counter + 1);

            self.emit(CounterIncreased { value: self.counter.read() });
        }
    }

}