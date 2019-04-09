----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:38:33 11/10/2015 
-- Design Name: 
-- Module Name:    Game - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.Numeric_STD.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Game is
    Port ( 	clk 					: in   STD_LOGIC;
				SW0,SW1,SW2,SW3 	: in   STD_LOGIC;
				DAC_CLK 				: out  STD_LOGIC;
				H 						: out  STD_LOGIC;
				V 						: out  STD_LOGIC;
				Bout 					: out  STD_LOGIC_VECTOR (7 downto 0);
				Gout 					: out  STD_LOGIC_VECTOR (7 downto 0);
				Rout 					: out  STD_LOGIC_VECTOR (7 downto 0)
				);
end Game;

architecture Behavioral of Game is
-- For VGA Horizontal Parameters
	--Complete Line 	: 800 CC
	--Front Porch 		: 16  CC
	--Sync Pulse		: 96  CC
	--Back Porch			: 48  CC
	--Active Image Area	: 640 CC
	
-- For VGA Vertical Parameters
	--Complete Line 	: 525 Lines
	--Front Porch 		: 10  Lines
	--Sync Pulse		: 2  Lines
	--Back Porch			: 33  Lines
	--Active Image Area	: 480 Lines

	signal x, y, VSync, HSync, hBP, vBP	: Integer := 0;
	signal sR,sB,sG 			: STD_LOGIC_VECTOR(7 downto 0):= "00000000";
	signal sH, sV,sDAC_CLK : STD_LOGIC :='0';

------------------------------------------------------------------
--Graphics

--Paddles:
--------- Each paddle will have x, y coordinate incidating the center. Paddle will be 61 pixels by 21
	--Height 30 Up and down from x
	--Width  10 left and right from y
	signal Pad1x : integer := 60;
	signal Pad1y : integer := 240;
	signal Pad2x : integer := 580;
	signal Pad2y : integer := 240;
	
--Ball  -- radius of 5 pixels
	signal ballx : integer := 80;
	signal bally : integer := 80;
	signal ball_motion_X :integer := 1; --By Default move to the right
	signal ball_motion_Y :integer := 0;
begin

	--Produce PixClock
	process(clk)
	begin
		if (rising_edge(clk)) then
			sDAC_CLK <= NOT(sDAC_CLK);
		end if;
	end process;
	
	--H and V Counters
	process(sDAC_CLK)
	begin
	if (rising_edge(sDAC_CLK)) then
		if (HSync < 800 -1) then
			HSync <= HSync + 1;
		else
			HSync <= 0;
			if (VSync < 525 - 1) then
				VSync <= VSync + 1;
			else
				VSync <= 0;
			end if;
		end if;
	end if;
	end process;
	
--Parallel Code
	
	--h_sync
	--HI for 640+FP (16)
	--LOW for 96
	--Hi for BP(48) + 640 + FP 	
	sH <=
			'1' when (HSync < 640 + 16) OR (HSync > 640 + 16 + 96) else  -- HI when NOT signal Pulse 
			'0';
	
	--v_sync
	--HI for 480 + 10
	--Low for 2
	--HI for 480 + 10 + 33
	sV <=
			'1' when (VSync < 480 + 10) OR (VSync > 480 + 10 + 2) else 
			'0';
			
	x <=
			HSync when (HSync < 640) else
			X;
	
	y <= 
			VSync when (VSync < 480) else
			X;
	
--PONG GAME Logic:
	
	--Paddle Movement
	--SW0: Player 1 UP, SW1: Player 1 DOWN
	process(sV)
	begin
	if (sV='1') then
		if ((SW0 XOR SW1)= '1') then
			if (SW0 = '1' AND Pad1y - 30 > 0) then -- Move up slowly
				Pad1y <= Pad1y - 1;
			elsif (SW1 = '1' AND Pad1y + 30 < 480) then --Move down slowly
				Pad1y <= Pad1y + 1;
			end if;
		end if;
	end if;
	end process;
	
	--SW2: Player 2 UP, SW3: Player 2 DOWN
	process(sV)
	begin
	if (sV='1') then
		if ((SW2 XOR SW3) = '1') then		
			if (SW2 = '1' AND Pad2y - 30 > 0) then
				Pad2y <= Pad2y - 1;
			elsif (SW3 = '1' AND Pad2y + 30 < 480) then 
				Pad2y <= Pad2y + 1;
			end if;
		end if;
	end if;
	end process;
	
	
	--Ball Movement
	process(sV)
	begin
	if (sV = '1') then
		--Check for collision
		if (ballx + ball_motion_X +5 > 640  OR ballx + ball_motion_X - 5 < 0) then -- assuming borders of 0 and 640
			ball_motion_X <= -ball_motion_X;
		elsif (bally + ball_motion_Y + 5 > 480 OR bally +ball_motion_Y -5 < 0) then
			ball_motion_Y <= -ball_motion_Y;
		end if;
		ballx <= ballx + ball_motion_X;
		bally <= bally + ball_motion_Y;
	end if;
	end process;
	
	
	--Set Colors/Pixel
	process (sDAC_CLK)
	begin
			if (VSync < 480 AND HSync < 640) then -- Active Region
				--Create Red Borders
				if ((y < 10) OR (y > 470)) then
					sR <= "11111111";
					sG <= "00000000";
					sB <= "00000000";
				--Create that '|-|' barrier then
				elsif((y > 15 AND y < 40) AND (x > 30 AND x < 610)) then
					sR <= "11111111";
					sG <= "11111111";
					sB <= "11111111";
			   --Create Yellow Dividing Line in the Center
				elsif ((x > 315 AND x < 325) AND (y > 40 AND y < 440)) then
					sR <= "11111111";
					sG <= "11111111";
					sB <= "00000000";
				else
					sR <= "00000000";
					sG <= "00000000";
					sB <= "00000000";
				end if;	
			else -- Blanking Region
				sR <= "00000000";
				sG <= "00000000";
				sB <= "00000000";
			end if;
	end process; 
	
	--Assign signals to Ouputs
	DAC_CLK <= sDAC_CLK;
	Rout <= sR;
	Gout <= sG;
	Bout <= sB;
	H	  <= sH;
	V	  <= sV;

end Behavioral;