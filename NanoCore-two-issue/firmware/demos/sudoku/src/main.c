#include "firmware.h"
// #include <stdio.h>

/** global variability */
#define N 9
int board[9][9] = {	{1, 0, 8, 6, 0, 0, 0, 0, 7},
					{0, 0, 0, 5, 8, 4, 0, 0, 0},
					{3, 0, 5, 1, 0, 0, 0, 0, 0},
					{6, 2, 1, 0, 0, 0, 0, 7, 0},
					{0, 7, 0, 0, 5, 0, 0, 6, 0},
					{0, 5, 0, 0, 0, 0, 9, 8, 1},
					{0, 0, 0, 0, 0, 8, 7, 0, 6},
					{0, 0, 0, 7, 1, 5, 0, 0, 0},
					{7, 0, 0, 0, 0, 3, 8, 0, 5}};


bool is_row_valid(int row, int num)         //判断本行是否有此数
{
    for (int col = 0; col < N; col++)
    {
        if (board[row][col] == num)
            return false;
    }
    return true;
}
bool is_col_valid(int col, int num)         //判断本列是否有此数
{
    for (int row = 0; row < N; row++)
    {
        if (board[row][col] == num)
            return false;
    }
    return true;
}
bool is_box_valid(int box_start_row, int box_start_col, int num)        //判断这个9宫格是否有此数
{
    for (int row = 0; row < 3; row++)
    {
        for (int col = 0; col < 3; col++)
        {
            if (board[row + box_start_row][col + box_start_col] == num)
                return false;
        }
    }
    return true;
}
bool is_valid(int row, int col, int num)        //判断此数是否适合本位置
{
    int box_start_row = row - row % 3;
    int box_start_col = col - col % 3;
    return is_row_valid(row, num) && is_col_valid(col, num) && is_box_valid(box_start_row, box_start_col, num);
}

bool solve_sudoku(int row, int col) {
    if (row == N) {
        return true;
    }
    if (board[row][col] != 0) {
        if (col == N - 1)
            return solve_sudoku(row + 1, 0);
        else
            return solve_sudoku(row, col + 1);
    }
    for (int num = 1; num <= N; num++) {
        if (is_valid(row, col, num)) {
            board[row][col] = num;
            if (col == N - 1) {
                if (solve_sudoku(row + 1, 0))
                    return true;
            }
            else {
                if (solve_sudoku(row, col + 1))
                    return true;
            }
            board[row][col] = 0;
        }
    }
    return false;
}

void print_board() {
    for (int row = 0; row < N; row++) {
        for (int col = 0; col < N; col++)
            printf("%d ", board[row][col]);
        printf("\n\r");
    }
}

// int mainRISCVshudu (void){
void main(void){
    printf("\rsystem boot finished\r\n");
	
    if (solve_sudoku(0, 0)) {
        print_board();
    }
    else {
        printf("No solution.\n\r");
    }

	while(1);
}
