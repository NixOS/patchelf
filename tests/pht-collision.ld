SECTIONS {
  .pht : { *(.pht) }
  .adjacent_data : { *(.adjacent_data) }
} INSERT BEFORE .dynamic;
