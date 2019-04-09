
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.Numeric_STD.ALL;


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

--VGA Control & Color Signals
	signal x, y, VSync, HSync, hBP, vBP	: Integer := 0;
	signal sR,sB,sG 			: STD_LOGIC_VECTOR(7 downto 0):= "00000000";
	signal sH, sV,sDAC_CLK : STD_LOGIC :='0';

------------------------------------------------------------------
--Graphics

--Paddles: Each paddle will have x, y coordinate incidating the center. Paddle will be 61 pixels by 21
--			  Height 30 Up and down from x
--			  Width  10 left and right from y
	
	--X position for paddles 
	signal Pad1y : integer := 240;
	signal Pad2y : integer := 240;
	--Used to slow down the paddles and the ball
	signal pad1counter, pad2counter, ballcounter : integer;
	
--Ball  -- radius of 5 pixels, x and y coordinate
	signal ballx : integer := 200;
	signal bally : integer := 240;
	
	--Motion Vector for the ball
	signal ball_motion_X :integer := 1; 
	signal ball_motion_Y :integer := 1;

--Score
	signal score1,score2 : integer :=0;
	--Pause: is used to freeze the ball for 20 DAC CLKs after a goal is made. Also used change the color of ball
	signal pause			: integer :=0;
begin

	--Produce PixClock by cuting the clk in half
	process(clk)
	begin
		if (rising_edge(clk)) then
			sDAC_CLK <= NOT(sDAC_CLK);
		end if;
	end process;
	
	--H and V Counters - used to generate H sync and v sync
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
			'1' when (HSync < 640 + 16) OR (HSync > 640 + 16 + 96) else  -- Hi whenever signal pulse is not active
			'0';
	
	--v_sync
	--HI for 480 + 10
	--Low for 2
	--HI for 480 + 10 + 33
	sV <=
			'1' when (VSync < 480 + 10) OR (VSync > 480 + 10 + 2) else -- Hi whenever signal pulse is not active
			'0';
			
	--the x and y coordinates point to the current pixel being drawn		
	x <=
			HSync when (HSync < 640) else 
			X;
	
	y <= 
			VSync when (VSync < 480) else
			X;
	
--PONG GAME Logic:
	
	--Paddle Movement
	--SW0: Player 1 UP, SW1: Player 1 DOWN
	--Update paddle coordinates ~ every 1/60 s 
	process(sDAC_CLK)
	begin
	if (rising_edge(sDAC_CLK)) then
		pad1counter <= pad1counter +1;
		if (pad1counter > 300000) then --Slows down the paddle movement
			pad1counter <= 0;
			if ((SW0 XOR SW1)= '1') then
				if (SW0 = '1' AND Pad1y - 30 > 30) then -- Prevent the paddle from crossing the borders
					Pad1y <= Pad1y - 1;
				elsif (SW1 = '1' AND Pad1y + 30 < 450) then -- Prevent the paddle from crossing the borders
					Pad1y <= Pad1y + 1;
				end if;
			end if;
		end if;
	end if;
	end process;
	
	--SW2: Player 2 UP, SW3: Player 2 DOWN
	--Update paddle coordinates ~ every 1/60 s 
	process(sDAC_CLK)
	begin
	if (rising_edge(sDAC_CLK)) then
		pad2counter <= pad2counter + 1;
		if (pad2counter > 300000) then -- Slows down the paddle movement
				pad2counter <= 0;
			if ((SW2 XOR SW3) = '1') then		
				if (SW2 = '1' AND Pad2y - 30 > 30) then -- Prevent the paddle from crossing the borders
					Pad2y <= Pad2y - 1;
				elsif (SW3 = '1' AND Pad2y + 30 < 450) then  -- Prevent the paddle from crossing the borders
					Pad2y <= Pad2y + 1;
				end if;
			end if;
		end if;
	end if;
	end process;
	
	--Ball Movement
	--Ball moves faster than paddles
	process(sDAC_CLK)
	begin
	if (rising_edge(sDAC_CLK)) then
		ballcounter <= ballcounter + 1;
		if (ballcounter > 175000) then
			ballcounter <= 0;
			--Check for goal  	320>y>160
			--Player1                                               --   TOP of GOAL                    -- Bottom of goal
			--Check for end game condition (ie. Either play scores 4 points)
			if (score1 = 4 OR score2 = 4) then
					ballx <= 320;
					bally <= 240;
					score1 <= 0;
					score2 <= 0;
			end if;
			--Checks if player 1 scored a goal
			if (((ballx + ball_motion_X - 8) < 40) AND ( ((bally + ball_motion_Y - 8) > 160) AND ((bally + ball_motion_Y + 8) < 320 ) )) then
					pause <= pause + 1;
					if (pause = 20) then
						ballx <= 320;
						bally <= 240;
						score1 <= score1 + 1;
						pause <= 0;
						
					end if;
			---Checks if player 2 scored a goal		
			elsif (((ballx + ball_motion_X + 8) > 600) AND ( ((bally + ball_motion_Y - 8) > 160) AND ((bally + ball_motion_Y + 8) < 320 ) )) then
					pause <= pause + 1;
					if (pause = 20) then
						ballx <= 320;
						bally <= 240;
						score2 <= score2 + 1;
						pause <= 0;
					end if;
			else
				--Check for collision between ball and  paddles (back and front)
				if ( (((ballx + ball_motion_X - 8 < 70) AND (ballx + ball_motion_X + 8 > 65)) AND ( (pad1y+30 > bally + ball_motion_Y + 8 ) AND (pad1y-30 < bally + ball_motion_Y - 8) ) ) OR (((ballx + ball_motion_X + 8 > 575) AND (ballx + ball_motion_X - 8 < 580)) AND ( (pad2y+30 > bally + ball_motion_Y + 8 ) AND (pad2y-30 < bally + ball_motion_Y - 8) ))) Then
					ball_motion_X <= -ball_motion_X;
					ball_motion_Y <= -ball_motion_Y;
				else
					--Check for collision with borders
					if ((ballx + ball_motion_X +8 > 600)  OR (ballx + ball_motion_X - 8 < 40) ) then 
						ball_motion_X <= -ball_motion_X;
					elsif (bally + ball_motion_Y + 8 > 450 OR bally +ball_motion_Y -8 < 30) then
						ball_motion_Y <= -ball_motion_Y;
					end if;
				end if;
			-- Updates  the ball condition with the ball motion vector
			ballx <= ballx + ball_motion_X;
			bally <= bally + ball_motion_Y;
			end if;
		end if;
	end if;
	end process;
	
	--Background drawing process
	process (sDAC_CLK)
	begin
			if (VSync < 480 AND HSync < 640) then -- Active Region
				if(  ((y > 20 AND y < 30) AND (x > 30 AND x < 610)) OR ((y < 460 AND y>450) AND (x > 30 AND x < 610)) OR (((y>20 AND y<160) OR (y>320 AND y<460)) AND (x>30 AND x<40)) OR (((y>20 AND y<160) OR (y>320 AND y<460)) AND (x>600 AND x<610))) then
					sR <= "11111111";
					sG <= "11111111";
					sB <= "11111111";
			   --Create Black Dividing Line in the Center
				elsif ((x > 318 AND x < 322) AND ((y>60 AND y<100) OR (y>140 AND y<180) OR  (y>220 AND y<260) OR  (y>300 AND y<340) OR  (y>380 AND y<420))) then
					sR <= "00000000";
					sG <= "00000000";
					sB <= "00000000";
						--Draw Paddle One (left)                -Back    -Front
					elsif ((y>(Pad1y-30) AND y<(Pad1y+30)) AND (x>65 AND x<70)) then
						sB <= "00000000";	
						sR <= "11111111";
						sG <= "00000000";							
						--Draw Paddle 2 (right)							  -Front		-Back
					elsif ((y>(Pad2y-30) AND y<(Pad2y+30)) AND (x>570 AND x<575)) then
						sB <= "11111111";
						sR <= "00000000";
						sG <= "00000000";
						--Draw the ball
					elsif(((y > (bally-8)) AND (y < (bally+8)))  AND ((x > (ballx-8)) AND (x < (ballx+8)))) then
							if (pause > 0) then -- A goal was scored recently, then flash the ball for a frame as Red
							sR <= "11111111";
							sG <= "00000000";
							sB <= "00000000";
						else
							sR <= "11111111"; -- Yellow
							sG <= "11111111";
							sB <= "00000000";

						end if;
					else
						--Make everything else Green
						sR <= "00000000"; 
						sG <= "11111111";
						sB <= "00000000";
				end if;	
				
			else -- Blanking Region must be black
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