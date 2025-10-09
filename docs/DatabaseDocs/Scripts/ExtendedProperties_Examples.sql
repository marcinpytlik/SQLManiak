-- Examples: add MS_Description to table and column
EXEC sys.sp_addextendedproperty 
    @name = N'MS_Description',
    @value = N'Tabela przechowuje zamówienia klientów',
    @level0type = N'SCHEMA', @level0name = 'Sales',
    @level1type = N'TABLE',  @level1name = 'Order';

EXEC sys.sp_addextendedproperty 
    @name = N'MS_Description',
    @value = N'Kwota zamówienia w walucie bazowej',
    @level0type = N'SCHEMA', @level0name = 'Sales',
    @level1type = N'TABLE',  @level1name = 'Order',
    @level2type = N'COLUMN', @level2name = 'TotalAmount';
