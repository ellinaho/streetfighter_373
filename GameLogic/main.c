void main(void)
{
  // initialize SSP
  uint16_t SSP0CPSR = 0x02;  // SSP max speed
  uint16_t SSP0CR0 = 0x07;  // SSP max speed, 8 bits
  uint16_t SSP0CR1 = 0x02;  // SSP master mode
  uint16_t PINSEL1 = 0x2A8;  // SSP mode for pins P0.17 to P0.20

  while(1)
  {
    // send two bytes
    uint16_t SSP0DR = 0x55;  // one nice thing about the SSP is that it has a 8-words deep FIFO
    uint16_t SSP0DR = 0x54;  // so here we write the data to be sent without worrying

    // now wait until both bytes are sent
    while(!(SSP0SR & 0x01));

    // now we can read the two bytes received... and do anything with them
    int data1 = SSP0DR;
    int data2 = SSP0DR;
    // ...
  }
}


void send_p1_packet() {
    uint8_t packet[4];
    packet[0] = 0xA1; // Unique header for P1
    
    // Bit-packing
    packet[1] = (p1_H_move << 6) | (p1_jump << 5);
    packet[2] = (p1_punch_valid << 7) | (p1_punch_val << 4) | 
                (p1_kick_valid << 3) | (p1_kick_val);
    packet[3] = (p1_powerup_valid << 7) | (p1_powerup_val << 4);

    HAL_GPIO_WritePin(GPIOA, SPI_CS_Pin, GPIO_PIN_RESET); // Select FPGA
    HAL_SPI_Transmit(&hspi1, packet, 4, 10);
    HAL_GPIO_WritePin(GPIOA, SPI_CS_Pin, GPIO_PIN_SET);   // Deselect
}