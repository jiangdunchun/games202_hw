function getRotationPrecomputeL(precompute_L, rotationMatrix){
	//console.log("getRotationPrecomputeL----------------->");
	//console.log("precompute_L: " + precompute_L);
	//console.log("rotationMatrix: " + rotationMatrix);

	let math_rotationMatrix = mat4Matrix2mathMatrix(rotationMatrix);

	let m = math.zeros(9, 9);
	m._data[0][0] = 1.0;

	let m33 = computeSquareMatrix_3by3(math_rotationMatrix);
	for (i = 0; i < 3; i++) {
		for (j = 0; j < 3; j++) {
			m._data[i + 1][j + 1] = m33._data[i][j];
		}
	}
	//console.log("m33: " + m33);

	let m55 = computeSquareMatrix_5by5(math_rotationMatrix);
	for (i = 0; i < 5; i++) {
		for (j = 0; j < 5; j++) {
			m._data[i + 4][j + 4] = m55._data[i][j];
		}
	}
	//console.log("m55: " + m55);

	//console.log("m: " + m);

	return math.multiply(m, precompute_L);
}

function computeSquareMatrix_3by3(rotationMatrix){ // 计算方阵SA(-1) 3*3 
	
	// 1、pick ni - {ni}
	let n1 = [1, 0, 0, 0]; 
	let n2 = [0, 0, 1, 0]; 
	let n3 = [0, 1, 0, 0];

	// 2、{P(ni)} - A  A_inverse
	// let A = math.matrix([[n1[0], n1[1], n1[2]],
	// 					 [n2[0], n2[1], n2[2]], 
	// 					 [n3[0], n3[1], n3[2]]]);

	let A = math.matrix([[n1[0], n2[0], n3[0]],
						 [n1[1], n2[1], n3[1]], 
						 [n1[2], n2[2], n3[2]]]);
	// console.log("computeSquareMatrix_3by3---------------------->");
	// console.log("A: " + A);
	let A_inverse = math.inv(A);
	// console.log("A_inverse: " + A_inverse);

	// 3、用 R 旋转 ni - {R(ni)}
	let n1_p = math.multiply(rotationMatrix, n1); 
	let n2_p = math.multiply(rotationMatrix, n2); 
	let n3_p = math.multiply(rotationMatrix, n3); 
	// console.log("n1_p: " + n1_p);
	// console.log("n2_p: " + n2_p);
	// console.log("n3_p: " + n3_p);

	// 4、R(ni) SH投影 - S
	let pSH_1 = SHEval(n1_p._data[0], n1_p._data[1], n1_p._data[2], 3);
	let pSH_2 = SHEval(n2_p._data[0], n2_p._data[1], n2_p._data[2], 3);
	let pSH_3 = SHEval(n3_p._data[0], n3_p._data[1], n3_p._data[2], 3);
	// console.log("pSH_1: " + pSH_1);
	// console.log("pSH_2: " + pSH_2);
	// console.log("pSH_3: " + pSH_3);

	// let S = math.matrix([[pSH_1[1], pSH_1[2], pSH_1[3]],
	// 					 [pSH_2[1], pSH_2[2], pSH_2[3]], 
	// 					 [pSH_3[1], pSH_3[2], pSH_3[3]]]);

	let S = math.matrix([[pSH_1[1], pSH_2[1], pSH_3[1]],
						 [pSH_1[2], pSH_2[2], pSH_3[2]], 
						 [pSH_1[3], pSH_2[3], pSH_3[3]]]);
	// console.log("S: " + S);

	// 5、S*A_inverse
	return math.multiply(S, A_inverse);
}

function computeSquareMatrix_5by5(rotationMatrix){ // 计算方阵SA(-1) 5*5
	
	// 1、pick ni - {ni}
	let k = 1 / math.sqrt(2);
	let n1 = [1, 0, 0, 0]; 
	let n2 = [0, 0, 1, 0]; 
	let n3 = [k, k, 0, 0]; 
	let n4 = [k, 0, k, 0]; 
	let n5 = [0, k, k, 0];

	// 2、{P(ni)} - A  A_inverse
	// let A = math.matrix([[n1[0], n1[1], n1[2], 0.0, 0.0],
	// 					 [n2[0], n2[1], n2[2], 0.0, 0.0], 
	// 					 [n3[0], n3[1], n3[2], 0.0, 0.0],
	// 					 [n4[0], n4[1], n4[2], 1.0, 0.0],
	// 					 [n5[0], n5[1], n5[2], 0.0, 1.0]]);

	let A = math.matrix([[n1[0], n2[0], n3[0], n4[0], n5[0]],
						 [n1[1], n2[1], n3[1], n4[1], n5[1]], 
						 [n1[2], n2[2], n3[2], n4[2], n5[2]],
						 [0.0, 0.0, 0.0, 1.0, 0.0],
						 [0.0, 0.0, 0.0, 0.0, 1.0]]);
	//console.log("A: " + A);
	let A_inverse = math.inv(A);
	//console.log("A_inverse: " + A_inverse);

	// 3、用 R 旋转 ni - {R(ni)}
	let n1_p = math.multiply(rotationMatrix, n1); 
	let n2_p = math.multiply(rotationMatrix, n2); 
	let n3_p = math.multiply(rotationMatrix, n3); 
	let n4_p = math.multiply(rotationMatrix, n4);
	let n5_p = math.multiply(rotationMatrix, n5);

	// 4、R(ni) SH投影 - S
	let pSH_1 = SHEval(n1_p._data[0], n1_p._data[1], n1_p._data[2], 3);
	let pSH_2 = SHEval(n2_p._data[0], n2_p._data[1], n2_p._data[2], 3);
	let pSH_3 = SHEval(n3_p._data[0], n3_p._data[1], n3_p._data[2], 3);
	let pSH_4 = SHEval(n4_p._data[0], n4_p._data[1], n4_p._data[2], 3);
	let pSH_5 = SHEval(n5_p._data[0], n5_p._data[1], n5_p._data[2], 3);

	// let S = math.matrix([[pSH_1[4], pSH_1[5], pSH_1[6], pSH_1[7], pSH_1[8]],
	// 					 [pSH_2[4], pSH_2[5], pSH_2[6], pSH_2[7], pSH_2[8]], 
	// 					 [pSH_3[4], pSH_3[5], pSH_3[6], pSH_3[7], pSH_3[8]],
	// 					 [pSH_4[4], pSH_4[5], pSH_4[6], pSH_4[7], pSH_4[8]],
	// 					 [pSH_5[4], pSH_5[5], pSH_5[6], pSH_5[7], pSH_5[8]]]);

	let S = math.matrix([[pSH_1[4], pSH_2[4], pSH_3[4], pSH_4[4], pSH_5[4]],
						 [pSH_1[5], pSH_2[5], pSH_3[5], pSH_4[5], pSH_5[5]], 
						 [pSH_1[6], pSH_2[6], pSH_3[6], pSH_4[6], pSH_5[6]],
						 [pSH_1[7], pSH_2[7], pSH_3[7], pSH_4[7], pSH_5[7]],
						 [pSH_1[8], pSH_2[8], pSH_3[8], pSH_4[8], pSH_5[8]]]);


	// 5、S*A_inverse
	return math.multiply(S, A_inverse);
}

function mat4Matrix2mathMatrix(rotationMatrix){

	let mathMatrix = [];
	for(let i = 0; i < 4; i++){
		let r = [];
		for(let j = 0; j < 4; j++){
			r.push(rotationMatrix[i*4+j]);
		}
		mathMatrix.push(r);
	}
	return math.matrix(mathMatrix)

}

function getMat3ValueFromRGB(precomputeL){

    let colorMat3 = [];
    for(var i = 0; i<3; i++){
        colorMat3[i] = mat3.fromValues( precomputeL[0][i], precomputeL[1][i], precomputeL[2][i],
										precomputeL[3][i], precomputeL[4][i], precomputeL[5][i],
										precomputeL[6][i], precomputeL[7][i], precomputeL[8][i] ); 
	}
    return colorMat3;
}