function MLJModelInterface.fit(model::ImageClassifier,
                               verbosity::Int,
                               X_,
                               y_)

    data = collate(model, X_, y_)

    levels = MLJModelInterface.classes(y_[1])
    n_output = length(levels)
    n_input = size(X_[1])

    if scitype(first(X_)) <: GrayImage{A, B} where A where B
        n_channels = 1      # 1-D image
    else
        n_channels = 3      # 3-D color image
    end

    chain0 = build(model.builder, n_input, n_output, n_channels)
    chain = Flux.Chain(chain0, model.finaliser)

    optimiser = deepcopy(model.optimiser)

    chain, history = fit!(chain,
                          optimiser,
                          model.loss,
                          model.epochs,
                          model.lambda,
                          model.alpha,
                          verbosity,
                          model.acceleration,
                          data[1],
                          data[2])

    # `optimiser` is now mutated

    cache = (deepcopy(model), data, history, n_input, n_output, optimiser)
    fitresult = (chain, levels)

    report = (training_losses=history, )

    return fitresult, cache, report
end

function MLJModelInterface.predict(model::ImageClassifier, fitresult, Xnew)
    chain, levels = fitresult
    X = reformat(Xnew)
    probs = vcat([chain(X[:,:,:,idx:idx])'
                  for idx in 1:length(Xnew)]...)
    return MLJModelInterface.UnivariateFinite(levels, probs)
end

function MLJModelInterface.update(model::ImageClassifier,
                                  verbosity::Int,
                                  old_fitresult,
                                  old_cache,
                                  X,
                                  y)

    old_model, data, old_history, n_input, n_output, optimiser = old_cache
    old_chain, levels = old_fitresult

    optimiser_flag = model.optimiser_changes_trigger_retraining &&
        model.optimiser != old_model.optimiser

    keep_chain = !optimiser_flag && model.epochs >= old_model.epochs &&
        MLJModelInterface.is_same_except(model, old_model, :optimiser, :epochs)

    if keep_chain
        chain = old_chain
        epochs = model.epochs - old_model.epochs
    else
        if scitype(first(X)) <: GrayImage{A, B} where A where B
            n_channels = 1      # 1-D image
        else
            n_channels = 3      # 3-D color image
        end
        chain = Flux.Chain(build(model.builder, n_input, n_output, n_channels),
                           model.finaliser)
        data = collate(model, X, y)
        epochs = model.epochs
    end

    # we only get to keep the optimiser "state" carried over from
    # previous training if we're doing a warm restart and the user has not
    # changed the optimiser hyper-parameter:
    if !keep_chain ||
        !MLJModelInterface._equal_to_depth_one(model.optimiser,
                                              old_model.optimiser)
        optimiser = deepcopy(model.optimiser)
    end

    chain, history = fit!(chain,
                          optimiser,
                          model.loss,
                          epochs,
                          model.lambda,
                          model.alpha,
                          verbosity,
                          model.acceleration,
                          data[1],
                          data[2])
    if keep_chain
        # note: history[1] = old_history[end]
        history = vcat(old_history[1:end-1], history)
    end

    fitresult = (chain, levels)
    cache = (deepcopy(model), data, history, n_input, n_output, optimiser)
    report = (training_losses=history, )

    return fitresult, cache, report

end

MLJModelInterface.fitted_params(::ImageClassifier, fitresult) =
    (chain=fitresult[1],)

MLJModelInterface.metadata_model(ImageClassifier,
               input=AbstractVector{<:MLJModelInterface.Image},
               target=AbstractVector{<:Multiclass},
               path="MLJFlux.ImageClassifier",
               descr="A neural network model for making probabilistic predictions of a `GrayImage` target,
                given a table of `Continuous` features. ")
