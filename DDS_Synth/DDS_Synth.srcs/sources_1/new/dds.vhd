-- Copyright (c) 2007 Frank Buss (fb@frank-buss.de)
-- See license.txt for license

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.all;

entity DDS is
    generic (
        ddsAddressSize : natural;
        ddsWordSize    : natural;
        ddsCounterSize : natural;
        outputSize     : natural
    );
    port(
        clock		: in std_logic;
		reset		: in std_logic;
		ramAddr		: out unsigned(ddsAddressSize - 1 downto 0);
		ramData 	: in unsigned(ddsWordSize - 1 downto 0);
		step		: in unsigned(ddsCounterSize - 1 downto 0);
		interpolate	: in std_logic;
		output		: out unsigned(outputSize - 1 downto 0);
        newOutput   : out std_logic
    );
end entity DDS;

architecture rtl of DDS is

	signal counter : unsigned(ddsCounterSize downto 0);

	type stateType is (
		loadAddress1,
		address1Wait1,
		address1Wait2,
		loadAddress2,
		address2Wait1,
		address2Wait2,
		setOutput,
		delay
	);
	signal state : stateType := loadAddress1;
	signal data1 : signed(outputSize downto 0);
    signal delayCounter : natural range 0 to 43;

begin
    process(clock, reset)
        variable delta : signed(outputSize downto 0);
        variable signedFraction : signed(ddsCounterSize - ddsAddressSize downto 0);
        variable interpolatedProduct : signed(ddsCounterSize - ddsAddressSize + outputSize + 1 downto 0);
        variable interpolated : signed(outputSize downto 0);
    begin
        if reset = '1' then
            counter <= (others => '0');
        elsif rising_edge(clock) then
			case state is
                -- set address for getting the first word from memory
				when loadAddress1 =>
                    newOutput <= '0';
					ramAddr <= counter(ddsCounterSize - 1 downto ddsCounterSize - ddsAddressSize);
					state <= address1Wait1;
                    
                -- some wait cycles, until word is loaded
				when address1Wait1 =>
					state <= address1Wait2;
				when address1Wait2 =>
					state <= loadAddress2;
                    
                -- get first word from memory and set address for getting next word for interpolating
				when loadAddress2 =>
					data1 <= signed('0' & ramData) & to_signed(0, outputSize - ddsWordSize);
					ramAddr <= counter(ddsCounterSize - 1 downto ddsCounterSize - ddsAddressSize) + 1;
					state <= address2Wait1;

                -- some wait cycles, until word is loaded
				when address2Wait1 =>
					state <= address2Wait2;
				when address2Wait2 =>
					state <= setOutput;
                    
                -- interpolate with lower bits of counter between first and second word and set output
				when setOutput =>
					if interpolate = '1' then
						delta := signed('0' & ramData) & to_signed(0, outputSize - ddsWordSize);
						delta := delta - data1;
						signedFraction := signed('0' & counter(ddsCounterSize - ddsAddressSize - 1 downto 0));
						interpolatedProduct := delta * signedFraction;
						interpolated := interpolatedProduct(interpolatedProduct'high - 1 downto interpolatedProduct'high - outputSize - 1);
						interpolated := interpolated + data1;
                        output <= unsigned(interpolated(outputSize - 1 downto 0));
					else
                        output <= unsigned(data1(outputSize - 1 downto 0));
					end if;
					counter <= counter + step;
                    delayCounter <= 42;
                    state <= delay;
                    
                -- add some wait cycles for 1us
                when delay => 
                    if delayCounter = 0 then
                        newOutput <= '1';
                        state <= loadAddress1;
                    else
                        delayCounter <= delayCounter - 1;
                    end if;
			end case;
        end if;
    end process;
end architecture rtl;