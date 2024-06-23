// this is a comment
/*
    This line is also a multiline comment
*/

// Identifiers: maximum character 64 , a-z, A-Z, 0-9, _, first character should not be a digit

// char type: 1 byte of memory (8 bits)  2^8=256  [-128, 128]
char cha = -12;

// uchar type: like char type but only positive values [0, 128]
uchar uch = 12;

// short type: 2 byte of memory 2^16, contain positive and negative numbers
short sh = -5000;

// ushort type:  like ushort type but only positive values [0, 128]
ushort ush = -5000;

// int type: 4 byte or 2^32, positive and negative
int in = -2445777;

// int type: like int but only positive numbers
uint uin = 2445777;

// long type: 8 byte or 2^64, positive and negative
long lon = -654646464;

// long type: like long but only positive numbers
ulong ulon = -654646464;

void OnStart()
{
    uchar u_ch;

    for (char ch = -128; ch <= 127; ch++)
    {
        u_ch = ch;
        Print("ch = ", ch, "u_ch = ", u_ch);
        if (ch == 127)
            break;
    }
}