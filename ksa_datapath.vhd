library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ksa_datapath is
    port(
        clk_i               : in std_logic;
        rst_i               : in std_logic;
		  
        fill_i              : in std_logic;
        fill_done_o         : out std_logic;
        		  
		swap_read_i_i       : in std_logic;
		swap_compute_j_i    : in std_logic;
        swap_read_j_i       : in std_logic;
		swap_write_i_i      : in std_logic;
		swap_write_j_i      : in std_logic;
		swap_done_o         : out std_logic;

        decrypt_read_i      : in std_logic;
        decrypt_read_j      : in std_logic;
        decrypt_write_i     : in std_logic;
        decrypt_write_j     : in std_logic;
        decrypt_read_k      : in std_logic;
        decrypt_write_k     : in std_logic;
        decrypt_done_o      : out std_logic;

        check_i             : in  std_logic;
        check_done_o        : out std_logic;
        check_fail_o        : out std_logic;
        check_last_key_o    : out std_logic;
		  
        print_i		        : in std_logic;
        print_driver_i      : in std_logic;

        wren_w_o            : out std_logic;
        address_w_o         : out std_logic_vector(7 downto 0);
        data_w_o            : out std_logic_vector(7 downto 0);
        q_w_i	            : in std_logic_vector (7 downto 0);

        address_rom_o       : out std_logic_vector(4 downto 0);
        q_rom_i             : in std_logic_vector(7 downto 0);

        wren_d_o            : out std_logic;
        address_d_o         : out std_logic_vector(4 downto 0);
        data_d_o            : out std_logic_vector(7 downto 0);
		q_d_i	            : in std_logic_vector (7 downto 0);

        secret_key_o        : out std_logic_vector(23 downto 0)
    );
end entity;

architecture behaviour of ksa_datapath is


    -- Init State signals
    signal index_r          : unsigned(7 downto 0);

    -- Swap State signals
    signal swap_i_r         : unsigned(7 downto 0);
    signal swap_j_r         : unsigned(7 downto 0);
    signal swap_temp_r      : unsigned(7 downto 0);
    signal swap_done        : std_logic;
    signal swap_next_j      : unsigned(7 downto 0);
    signal secret_key_byte_index   : integer range 0 to 3;

    -- Decrypt State signals
    signal decrypt_i_r      : unsigned(7 downto 0);
    signal decrypt_j_r      : unsigned(7 downto 0);
    signal decrypt_k_r      : unsigned(4 downto 0);
    signal decrypt_s_i_r    : unsigned(7 downto 0);
    signal decrypt_s_j_r    : unsigned(7 downto 0);
    signal decrypt_done     : std_logic;
    signal decrypt_next_j   : unsigned(7 downto 0);

    constant MESSAGE_LENGTH : integer := 32;
	 
    -- Check state signals
    signal check_addr_r     : unsigned(4 downto 0);
    signal check_addr_d_r   : unsigned(4 downto 0);
    signal check_fail       : std_logic;

	signal print_address_r  : unsigned(4 downto 0);

    signal secret_key_r     : unsigned(23 downto 0);
    constant MAX_KEY        : unsigned(23 downto 0) := x"FFFFFF";
    
begin

    secret_key_o <= std_logic_vector(secret_key_r);



    -- Fill state logic
    process(clk_i, rst_i) begin
        if(rst_i = '1') then
            index_r <= to_unsigned(0, index_r'length);
        elsif(rising_edge(clk_i)) then
            if(fill_i = '1') then
                index_r <= index_r + to_unsigned(1, index_r'length);
            else
                index_r <= to_unsigned(0, index_r'length);
            end if;
        end if;
    end process;

    fill_done_o <= '1' when (index_r = 255) else '0';


	 


	-- Swap state logic
    process(clk_i, rst_i) begin
        if(rst_i = '1') then
            swap_i_r    <= to_unsigned(0, swap_i_r'length);
            swap_j_r    <= to_unsigned(0, swap_j_r'length);
            swap_temp_r <= to_unsigned(0, swap_temp_r'length);
				
        elsif(rising_edge(clk_i)) then
            if(swap_compute_j_i = '1') then
                swap_j_r <= swap_next_j;
                swap_temp_r <= unsigned(q_w_i);
            end if;

            if(swap_write_j_i = '1') then
                swap_i_r <= swap_i_r + 1;

                if(swap_done = '1') then
                    swap_i_r    <= to_unsigned(0, swap_i_r'length);
                    swap_j_r    <= to_unsigned(0, swap_j_r'length);
                    swap_temp_r <= to_unsigned(0, swap_temp_r'length);
                end if;
            end if;	

        end if;
    end process;

    secret_key_byte_index <= 2 - (to_integer(swap_i_r) mod 3);
    swap_next_j <= (swap_j_r + unsigned(q_w_i) + unsigned(secret_key_r(8 * secret_key_byte_index + 7 downto 8 * secret_key_byte_index)));
	 
    swap_done   <= '1' when (swap_i_r = 255) else '0';
    swap_done_o <= swap_done;



    -- Decrypt state logic
    process(clk_i, rst_i) begin
        if(rst_i = '1') then
            decrypt_i_r     <= to_unsigned(0, 8);
            decrypt_j_r     <= to_unsigned(0, 8);
            decrypt_k_r     <= to_unsigned(0, decrypt_k_r'length);
            decrypt_s_i_r   <= to_unsigned(0, 8);
            decrypt_s_j_r   <= to_unsigned(0, 8);
            
        elsif(rising_edge(clk_i)) then
            if(decrypt_read_i = '1') then
                decrypt_i_r <= decrypt_i_r + to_unsigned(1, 8);
            end if;

            if(decrypt_read_j = '1') then
                decrypt_s_i_r <= unsigned(q_w_i);
                decrypt_j_r <= decrypt_next_j;
            end if;

            if(decrypt_write_i = '1') then
                decrypt_s_j_r <= unsigned(q_w_i);
            end if;

            if(decrypt_write_k = '1') then
                decrypt_k_r <= decrypt_k_r + to_unsigned(1, decrypt_k_r'length);

                if(decrypt_done = '1') then
                    decrypt_i_r     <= to_unsigned(0, 8);
                    decrypt_j_r     <= to_unsigned(0, 8);
                    decrypt_k_r     <= to_unsigned(0, decrypt_k_r'length);
                    decrypt_s_i_r   <= to_unsigned(0, 8);
                    decrypt_s_j_r   <= to_unsigned(0, 8);
                end if;
            end if;

        end if;
    end process;	

    decrypt_done <= '1' when (decrypt_k_r = 31) else '0';
    decrypt_done_o <= decrypt_done;
    decrypt_next_j <= decrypt_j_r + unsigned(q_w_i);



    -- Check state logic
    process(clk_i, rst_i) begin
        if(rst_i = '1') then
            check_addr_r    <= to_unsigned(0, 5);
            check_addr_d_r  <= to_unsigned(0, 5);
            secret_key_r    <= to_unsigned(0, secret_key_r'length);

        elsif(rising_edge(clk_i)) then
            check_addr_d_r <= check_addr_r;

            if(check_i = '1') then
                check_addr_r <= check_addr_r + to_unsigned(1, 5);
            else
                check_addr_r <= to_unsigned(0, 5);
            end if;

            if(check_i = '1' and check_fail = '1' and secret_key_r < MAX_KEY) then
                secret_key_r <= secret_key_r + to_unsigned(1, secret_key_r'length);
            end if;
        end if;
    end process;

    check_last_key_o    <= '1' when (secret_key_r = MAX_KEY) else '0';
    check_done_o        <= '1' when (check_addr_d_r = 31) else '0';
    check_fail          <= '0' when (unsigned(q_d_i) = 32 or (unsigned(q_d_i) >= 97 and unsigned(q_d_i) <= 122)) else '1';
    check_fail_o        <= check_fail;
	 
    
	 
    -- Printing state logic
    process(clk_i, rst_i) begin
			if(rst_i = '1') then
				print_address_r <= to_unsigned(0, 5);
			elsif(rising_edge(clk_i)) then
				if(print_address_r < 32 AND print_driver_i = '1') then
					print_address_r <= print_address_r + 1;
				end if;
			end if;
	end process;



    -- Memory signal control
    process(
        fill_i,
        swap_read_i_i,
        swap_compute_j_i,
        swap_read_j_i,
        swap_write_i_i,
        swap_write_j_i,
        index_r,
        swap_i_r,
        swap_j_r,
        swap_temp_r,
        q_w_i,
        decrypt_read_i,
        decrypt_read_j,
        decrypt_read_k,
        decrypt_write_k,
        decrypt_write_i,
        decrypt_write_j,
        decrypt_i_r,
        decrypt_j_r,
        decrypt_next_j,
        decrypt_k_r,
        decrypt_s_i_r,
        decrypt_s_j_r,
        q_rom_i,
        check_i,
        check_addr_r,
		print_i,
		print_address_r,
		print_driver_i
    ) begin
        wren_w_o        <= '0';
        address_w_o     <= "00000000";
        data_w_o        <= "00000000";
        
        address_rom_o   <= "00000";
        
        wren_d_o        <= '0';
        address_d_o     <= "00000";
        data_d_o        <= "00000000";

        if(fill_i = '1') then
            wren_w_o        <= '1';
            address_w_o     <= std_logic_vector(index_r);
            data_w_o        <= std_logic_vector(index_r);
        end if;

        if(swap_read_i_i = '1') then
            address_w_o     <= std_logic_vector(swap_i_r);
        end if;

        if(swap_read_j_i = '1') then
            address_w_o     <= std_logic_vector(swap_j_r);
        end if;

        if(swap_write_i_i = '1') then
            wren_w_o        <= '1';
            address_w_o     <= std_logic_vector(swap_i_r);
            data_w_o        <= std_logic_vector(q_w_i);
        end if;

        if(swap_write_j_i = '1') then
            wren_w_o        <= '1';
            address_w_o     <= std_logic_vector(swap_j_r);
            data_w_o        <= std_logic_vector(swap_temp_r);
        end if;

        if(decrypt_read_i = '1') then
            address_w_o     <= std_logic_vector(decrypt_i_r + to_unsigned(1, 8));
        end if;

        if(decrypt_read_j = '1') then
            address_w_o     <= std_logic_vector(decrypt_next_j);
        end if;

        if(decrypt_write_i = '1') then
            wren_w_o        <= '1';
            address_w_o     <= std_logic_vector(decrypt_i_r);
            data_w_o        <= std_logic_vector(q_w_i);
        end if;

        if(decrypt_write_j = '1') then
            wren_w_o        <= '1';
            address_w_o     <= std_logic_vector(decrypt_j_r);
            data_w_o        <= std_logic_vector(decrypt_s_i_r);
        end if;

        if(decrypt_read_k = '1') then
            address_w_o     <= std_logic_vector(decrypt_s_i_r + decrypt_s_j_r);
            address_rom_o   <= std_logic_vector(decrypt_k_r);
        end if;

        if(decrypt_write_k = '1') then
            wren_d_o        <= '1';
            address_d_o     <= std_logic_vector(decrypt_k_r);
            data_d_o        <= std_logic_vector(q_w_i) xor std_logic_vector(q_rom_i);
        end if;
		
        if(check_i = '1') then
            address_d_o     <= std_logic_vector(check_addr_r);
        end if;
        
		if(print_i = '1') then
			wren_d_o        <= '0';
            address_d_o     <= std_logic_vector(print_address_r);
        end if;

    end process;
end architecture;