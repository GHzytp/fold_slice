% [Im] = nonlocalTV_GPU(Im0,CloseInd, Neighbours, Rwin,Niter,lambda, dt, eps)
% FUNCTION 
%   nonlocal total variation solved by a simple steepest descent solver 
% Inputs:
%     Im0 - regularized array (3D volume) 
%     CloseInd - close indices generated by nonlocalTV_weight code  
%     Neighbours - number of neighbors used for calculation 
%     Rwin - radius of the window used to find similar regions 
%     Niter - number of reconstruction iterations 
%     lambda - step size (tunning value), usually < 1, if zero ->
%           completelly ignore data and just find the solution that most fits to
%           nonlocal TV constraint 
%     dt - also kind of step size (tunning value), usually << 1
%     eps - regularization constant (tunning value), usually << 1
% RECOMPILE COMMAND
%   mexcuda -output +regularization/private/nonlocalTV_tex +regularization/private/TV_cuda_texture.cu +regularization/private/nonlocalTV_mex.cpp


%*-----------------------------------------------------------------------*
%|                                                                       |
%|  Except where otherwise noted, this work is licensed under a          |
%|  Creative Commons Attribution-NonCommercial-ShareAlike 4.0            |
%|  International (CC BY-NC-SA 4.0) license.                             |
%|                                                                       |
%|  Copyright (c) 2017 by Paul Scherrer Institute (http://www.psi.ch)    |
%|                                                                       |
%|       Author: CXS group, PSI                                          |
%*-----------------------------------------------------------------------*
% You may use this code with the following provisions:
%
% If the code is fully or partially redistributed, or rewritten in another
%   computing language this notice should be included in the redistribution.
%
% If this code, or subfunctions or parts of it, is used for research in a 
%   publication or if it is fully or partially rewritten for another 
%   computing language the authors and institution should be acknowledged 
%   in written form in the publication: “Data processing was carried out 
%   using the “cSAXS matlab package” developed by the CXS group,
%   Paul Scherrer Institut, Switzerland.” 
%   Variations on the latter text can be incorporated upon discussion with 
%   the CXS group if needed to more specifically reflect the use of the package 
%   for the published work.
%
% A publication that focuses on describing features, or parameters, that
%    are already existing in the code should be first discussed with the
%    authors.
%   
% This code and subroutines are part of a continuous development, they 
%    are provided “as they are” without guarantees or liability on part
%    of PSI or the authors. It is the user responsibility to ensure its 
%    proper use and the correctness of the results.

function [Im] = nonlocalTV_GPU(Im0,CloseInd, Neighbours, Rwin,Niter,lambda, dt, eps)

    keep_on_gpu = isa(Im0, 'gpuArray');

    CloseInd = gpuArray(uint8(CloseInd));
    Im0 = gpuArray(single(Im0));

    try
        %Input should be between 0 and 1 to make the regularizations constants selection
        %kind of repeatable for similar samples 
        minIm=min(Im0(:));
        Im0=Im0-minIm;
        maxIm=prctile(Im0(1:10:end), 99);
        Im0=Im0/maxIm;

    catch err
        error(err.message)

    end

    Nclose = size(CloseInd,ndims(CloseInd));



    %% primitive replacement of the real weights based on assumption that CloseInd is sorted by importance !!! 
    Nnbrs = size(CloseInd,ndims(CloseInd));
    % Nbrs_weights = single(exp(-linspace(0,1,Nnbrs)));
    Nbrs_weights = single(1./(1:Nnbrs));
    % Nbrs_weights = ones(Nnbrs,1, 'single');

    % keyboard

    % tic
    Im = nonlocalTV_tex(Im0,CloseInd,uint8(Neighbours), Nbrs_weights, dt, eps, lambda, Nclose, Rwin,Niter);
    % wait(gpu)
    % toc


    %Back to original pixel range
    Im=Im*maxIm;
    Im=Im+minIm;

    if ~keep_on_gpu
        Im = gather(Im);
    end


end