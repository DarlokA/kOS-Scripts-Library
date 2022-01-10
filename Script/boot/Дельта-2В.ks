CLEARSCREEN.
PRINT("Дельта-2В Updating:").
PRINT("HTOL....").
copypath("0:/HTOL.ks", "1:/").
if EXISTS("HTOL.ks") 
{
	PRINT "OK." AT(9, 1).
}else{
	PRINT "FAILED!" AT(9, 1).
}

run htol.