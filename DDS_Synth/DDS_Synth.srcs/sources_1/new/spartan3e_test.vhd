-- Copyright (c) 2007 Frank Buss (fb@frank-buss.de)
-- See license.txt for license

library IEEE;
use IEEE.STD_LOGIC_1164.ALL; 
use IEEE.NUMERIC_STD.ALL; 
use work.ALL;

entity spartan3e_test is
    port(
        CLK_50MHZ : in std_logic;
        led : out std_logic_vector(7 downto 0);
        SPI_SCK : out std_logic;
        SPI_MOSI : out std_logic;
        DAC_CLR : out std_logic;
        DAC_CS : out std_logic;
        btn_north : in std_logic;
        btn_south : in std_logic
    );
end entity spartan3e_test;

architecture rtl of spartan3e_test is

    constant ddsAddressSize : natural := 4;
    constant ddsWordSize    : natural := 3;
    constant ddsCounterSize : natural := 48;
    constant outputSize     : natural := 8;

    signal address  : unsigned(ddsAddressSize - 1 downto 0);
    signal data     : unsigned(ddsWordSize - 1 downto 0);
    signal q        : unsigned(ddsWordSize - 1 downto 0);
    signal wren     : std_logic := '0';

    signal output    : unsigned(outputSize - 1 downto 0);
    signal newOutput : std_logic := '0';


	type dacStateType is (
		idle,
		sendBit,
		clockHigh,
		csHigh
	);
	signal dacState   : dacStateType := idle;
	signal dacCounter : integer range 0 to 23;
	signal dacData    : unsigned(23 downto 0);

begin
    
    instanceDDS: entity DDS
    generic map (
        ddsAddressSize  => ddsAddressSize,
        ddsWordSize     => ddsWordSize,
        ddsCounterSize  => ddsCounterSize,
        outputSize      => outputSize
    )
    port map (
        clock       => CLK_50MHZ,
        reset       => btn_south,
        ramAddr		=> address,
        ramData 	=> q,
        -- for output frequency f use this formula:
        -- 2^(ddsCounterSize-ddsAddressSize) * f / 1MHz * 16samples
        -- e.g. for 1kHz ouput frequency:
        -- 2^(48-4) * 1kHz / 1MHz * 16samples = 281474976710,656 = 0x004189374BC7
        -- some other values for testing:
        -- 100kHz: 0x199999999999
        -- 10Hz:   0x0000A7C5AC47
        -- 0.1Hz:   0x000001AD7F2A
        step		=> x"004189374BC7",
        interpolate	=> btn_north,
        output		=> output,
        newOutput   => newOutput
    );
    
    process(CLK_50MHZ, btn_south, address, wren, data)
    begin
        if btn_south = '1' then
            dacState <= idle;
        elsif rising_edge(CLK_50MHZ) then
            -- simple RAM simulator
            case address is
                when "0000" => q <= "100";
                when "0001" => q <= "101";
                when "0010" => q <= "110";
                when "0011" => q <= "111";
                when "0100" => q <= "111";
                when "0101" => q <= "111";
                when "0110" => q <= "110";
                when "0111" => q <= "101";
                when "1000" => q <= "100";
                when "1001" => q <= "010";
                when "1010" => q <= "001";
                when "1011" => q <= "000";
                when "1100" => q <= "000";
                when "1101" => q <= "000";
                when "1110" => q <= "001";
                when "1111" => q <= "010";
                when others => q <= "000";
            end case;
            
            -- transfer data to DAC every us
            case dacState is
                when idle =>
                    if newOutput = '1' then
                        DAC_CS <= '0';
                        SPI_SCK <= '0';
                        dacState <= sendBit;
                        dacCounter <= 23;
                        dacData <= "0010" & "1111" & output & "00000000";
                    end if;
                when sendBit =>
                    SPI_SCK <= '0';
                    SPI_MOSI <= dacData(23);
                    dacData <= dacData(22 downto 0) & "0";
                    dacState <= clockHigh;
                when clockHigh =>
                    SPI_SCK <= '1';
                    if dacCounter = 0 then
                        dacState <= csHigh;
                    else
                        dacCounter <= dacCounter - 1;
                        dacState <= sendBit;
                    end if;
                when csHigh =>
                    DAC_CS <= '1';
                    dacState <= idle;
            end case;
        end if;
    end process;

    led <= std_logic_vector(output);
    DAC_CLR <= '1';

end architecture rtl;